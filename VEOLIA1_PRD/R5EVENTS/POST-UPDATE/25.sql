DECLARE
  evt           r5events%ROWTYPE;
  vmpcnt        NUMBER;
  vmpob         NUMBER;
  mtp           r5maintenancepatterns%ROWTYPE;
  vmpuom        r5maintenancepatterns.mtp_metuom%TYPE;
  metread       r5objusagedefs.oud_totalusage%TYPE;
  metdate       r5objusagedefs.oud_lastreaddate%TYPE;  
  vwodesc       r5events.evt_desc%TYPE;
  vmettogo      NUMBER;
  oud           R5objusagedefs%ROWTYPE;
  vsrtdate      r5events.evt_due%TYPE;
  vestusg       NUMBER;
  venddate      r5events.evt_schedend%TYPE;
  vmpchdcnt     NUMBER;
  vawo          NUMBER;
  vmpchk        NUMBER;
  vnewvalue     r5audvalues.ava_to%TYPE;
  voldvalue     r5audvalues.ava_from%TYPE;
  vtimediff     NUMBER;
  vmeterdue     r5events.evt_meterdue%TYPE;
  voutwo        r5events.evt_code%TYPE;
  chk           VARCHAR2(3);
  vmpchdchk     NUMBER;
  evttwo        r5events%ROWTYPE;
  vevtactstr    NUMBER;
  vactchk       NUMBER;
  vactrea       NUMBER;
  err           EXCEPTION;
  imsg          VARCHAR2(400);
  CURSOR chd_evt(vpwo VARCHAR) IS
    SELECT evt_code FROM R5EVENTS WHERE evt_parent = vpwo;
  CURSOR act_str(vwo VARCHAR,vstr DATE) IS
    SELECT act_act FROM R5ACTIVITIES WHERE act_event = vwo
      AND act_start != vstr;
  CURSOR act_chk(vwo VARCHAR) IS
    SELECT ack_code FROM R5ACTIVITIES,R5TASKS,R5ACTCHECKLISTS
      WHERE act_event = vwo
        AND NVL(act_udfchkbox04, '-') = '+'
        AND tsk_code = act_task
        AND tsk_revision = act_taskrev
        AND tsk_class = 'ZFLT-CHK'
        AND ack_act = act_act
        AND ack_event = act_event
        AND ack_requiredtoclose = 'YES';
  CURSOR act_rea(vwo VARCHAR) IS
    SELECT act_act FROM R5ACTIVITIES,R5TASKS
      WHERE act_event = vwo
        AND act_task LIKE '%-OPS-%'
        AND tsk_code = act_task
        AND tsk_revision = act_taskrev
        AND tsk_class = 'ZFLT-CHK';

BEGIN
  SELECT * INTO evt FROM R5EVENTS WHERE ROWID = :rowid;
  /* Assign R5EVENTOBJECTS if missing */
  SELECT COUNT(1) INTO vmpob FROM R5EVENTOBJECTS
  WHERE eob_event = evt.evt_code;
  IF vmpob = 0 AND evt.evt_type IN ('JOB','PPM')
    AND evt.evt_rstatus = 'R' THEN
    o7creob1( evt.evt_code,evt.evt_rtype,
      evt.evt_object, evt.evt_object_org,
      evt.evt_obtype, evt.evt_obrtype, chk );
  END IF;

  /* update MP WO Details */
  IF evt.evt_status = '25TP' AND evt.evt_mp IS NOT NULL
    AND NVL(evt.evt_printed,'-') = '-' THEN
    /* count MP */
    SELECT COUNT(1) INTO vmpcnt FROM R5MAINTENANCEPATTERNS
    WHERE mtp_code = evt.evt_mp
      AND mtp_org = evt.evt_mp_org
      AND mtp_revision = evt.evt_mp_rev
      AND NVL(mtp_allowduplicatewo,'-') = '-'
      AND NVL(mtp_class,'*') != '*'
      AND ((mtp_class = 'CBMT' AND mtp_releasetype IS NULL)
        OR (mtp_class = 'MTCB' AND mtp_releasetype = 'AV')
        OR (mtp_class = 'MTAV' AND mtp_releasetype = 'AV')
        OR (mtp_class = 'MTAD' AND mtp_releasetype = 'AD')
        OR (mtp_class = 'MTED' AND mtp_releasetype = 'ED'));
    /* MP exist*/
    IF vmpcnt > 0 THEN
      /* assign mp into mtp */
      SELECT * INTO mtp FROM R5MAINTENANCEPATTERNS
        WHERE mtp_code = evt.evt_mp
          AND mtp_org = evt.evt_mp_org
          AND mtp_revision = evt.evt_mp_rev;
      /* defaulting meter reading variable*/
      vmpuom := NULL;
      metread := NULL;
      metdate := NULL;
      vwodesc := evt.evt_desc;
      vmettogo := NULL;
      /* get last meter read from the right UOM for Meter MP*/
      IF NVL(mtp.mtp_metuom,'-') != '-' 
        AND NVL(evt.evt_meterdue,0) != 0 THEN
        BEGIN
          SELECT * INTO oud FROM R5OBJUSAGEDEFS
          WHERE oud_object = evt.evt_object
            AND oud_object_org = evt.evt_object_org
            AND oud_uom = mtp.mtp_metuom;
          /* update wo desc & met to go if reading exist*/
          IF NVL(oud.oud_totalusage,0) != 0 THEN
            vmpuom := mtp.mtp_metuom;
            metread := oud.oud_totalusage;
            metdate := oud.oud_lastreaddate;
            vwodesc := SUBSTR(evt.evt_desc||' - Due: '
              ||evt.evt_meterdue||' '||vmpuom,1,80);
            vmettogo := evt.evt_meterdue
              - NVL(oud.oud_totalusage, 0);
          END IF;
        EXCEPTION
          WHEN no_data_found THEN NULL;
        END;
      END IF;
      /* defaulting start date variable*/
      vsrtdate := TRUNC(NVL(evt.evt_due,SYSDATE));
      /* meter MP scenarios - Average & Estimate Release */
      IF (mtp.mtp_releasetype = 'AD' AND mtp.mtp_class = 'MTAD')
        OR (mtp.mtp_releasetype = 'ED' AND mtp.mtp_class = 'MTED') THEN
        vsrtdate := TRUNC(NVL(evt.evt_meterduedate,
          NVL(metdate,SYSDATE)));
      END IF;
      /* meter MP scenarios - Calender Backup */
      IF mtp.mtp_releasetype = 'AV' AND mtp.mtp_class = 'MTCB'
        AND evt.evt_due IS NOT NULL
        AND evt.evt_freq IS NOT NULL
        AND evt.evt_perioduom IS NOT NULL THEN
        vsrtdate := TRUNC(NVL(evt.evt_due,SYSDATE));
        IF NVL(metread,0) != 0 AND metread >= evt.evt_genwinbegval
          OR ( NVL(mtp.mtp_udfnum02,0) > 0 
            AND metread >= (evt.evt_meterdue - mtp.mtp_udfnum02) ) THEN
            vestusg := O7GTFREQ(evt.evt_freq,evt.evt_perioduom,
              TRUNC(SYSDATE)) / evt.evt_meterinterval;
            vsrtdate := TRUNC(NVL(metdate,SYSDATE)) +
              TRUNC((evt.evt_meterdue - metread)*vestusg);
          END IF;
        IF NVL(metread,0) != 0 AND metread >= evt.evt_meterdue THEN 
          vsrtdate := TRUNC(NVL(metdate,SYSDATE));
        END IF;
      END IF;
      /* meter MP scenarios - Calender Backup incomplete setup*/
      IF mtp.mtp_releasetype = 'AV' AND mtp.mtp_class = 'MTCB'
        AND (evt.evt_due IS NULL OR evt.evt_freq IS NULL
          OR evt.evt_perioduom IS NULL) THEN
          vsrtdate := TRUNC(NVL(metdate,SYSDATE));
      END IF;
      /* meter MP scenarios - Actual Release */
      IF mtp.mtp_releasetype = 'AV' AND mtp.mtp_class = 'MTAV' THEN
          vsrtdate := TRUNC(NVL(metdate,SYSDATE));
      END IF;
      /* defaulting end date variable*/
      venddate := vsrtdate + evt.evt_duration - 1;
      /* update MP WO Details*/
      UPDATE R5EVENTS
      SET
        evt_metuom = vmpuom,
        evt_failureusage = metread,
        evt_desc = vwodesc,
        evt_udfnum07 = vmettogo,
        evt_due = vsrtdate,
        evt_target = vsrtdate,
        evt_schedend = venddate,
        evt_requeststart = NULL,
        evt_requestend = NULL,
        evt_printed = '+'
      WHERE  ROWID = :rowid;
      /* count child MP */
      SELECT COUNT(1) INTO vmpchdcnt FROM R5EVENTS e
      WHERE e.evt_parent = evt.evt_code
        AND NVL(e.evt_printed,'-') = '-';
      /* manage MP with routes*/
      IF vmpchdcnt > 0 AND evt.evt_route IS NOT NULL THEN
        FOR cld_wo IN chd_evt(evt.evt_code) LOOP
          UPDATE R5EVENTS
          SET
            evt_metuom = vmpuom,
            evt_failureusage = metread,
            evt_desc = vwodesc,
            evt_udfnum07 = vmettogo,
            evt_due = vsrtdate,
            evt_target = vsrtdate,
            evt_schedend = venddate,
            evt_requeststart = NULL,
            evt_requestend = NULL,
            evt_printed = '+'
          WHERE evt_code = cld_wo.evt_code
            AND NVL(evt_printed,'-') = '-';
        END LOOP;
      END IF;
    END IF;
  END IF;
  /* release next WO */
  IF evt.evt_type IN ( 'PPM' )
    AND evt.evt_status = '25TP'
    AND evt.evt_mp IS NOT NULL THEN
    /* clear any stray evts with evt_status = A */
    DELETE FROM R5EVENTS
    WHERE evt_org = evt.evt_org
      AND evt_object = evt.evt_object
      AND evt_object_org = evt.evt_object_org
      AND evt_mp IS NULL AND evt_mp_seq IS NOT NULL
      AND evt_ppm IS NULL AND evt_status = 'A';
    /* get awaitng count */
    SELECT COUNT(1) INTO  vawo FROM  R5EVENTS
    WHERE evt_org = evt.evt_org AND evt_object = evt.evt_object
      AND evt_object_org = evt.evt_object_org
      AND evt_mp = evt.evt_mp AND evt_mp_org = evt.evt_mp_org
      AND evt_mp_rev = evt.evt_mp_rev AND evt_status = 'A'
      AND evt_code <> evt.evt_code;
    /* skip if evt_status = A is already exist*/
    IF vawo > 0 THEN
      RETURN;
    END IF;
    /* count MP */
    SELECT COUNT(1) INTO vmpchk FROM R5MAINTENANCEPATTERNS m,
      R5PATTERNSEQUENCES p
    WHERE m.mtp_code = evt.evt_mp
      AND m.mtp_org = evt.evt_mp_org
      AND m.mtp_revision = evt.evt_mp_rev
      AND NVL(m.mtp_allowduplicatewo,'-') = '-'
      AND NVL(m.mtp_class,'*') != '*'
      AND ((m.mtp_class = 'CBMT'
        AND NVL(m.mtp_releasetype,'-') = '-')
        OR (m.mtp_class = 'MTCB' AND m.mtp_releasetype = 'AV')
        OR (m.mtp_class = 'MTAV' AND m.mtp_releasetype = 'AV')
        OR (m.mtp_class = 'MTAD' AND m.mtp_releasetype = 'AD')
        OR (m.mtp_class = 'MTED' AND m.mtp_releasetype = 'ED'))
      AND p.psq_mp_org = m.mtp_org
      AND p.psq_mp = m.mtp_code
      AND p.psq_revision = m.mtp_revision
      AND p.psq_sequence = evt.evt_mp_seq
      AND p.psq_pk = evt.evt_psqpk
      AND p.psq_seqtype = 'D';
    /* MP exist*/
    IF vmpchk > 0 THEN
      /* check is status update? */
      BEGIN
        SELECT ava_to, ava_from, timediff
        INTO vnewvalue, voldvalue, vtimediff
        FROM (SELECT ava_to, ava_from,
          ABS(SYSDATE - ava_changed) * 24 * 60 * 60 AS timediff
          FROM R5AUDVALUES, R5AUDATTRIBS
          WHERE ava_table = aat_table AND ava_attribute = aat_code
            AND aat_table = 'R5EVENTS' AND aat_column IN ('EVT_STATUS')
            AND ava_table = 'R5EVENTS' AND ava_primaryid = evt.evt_code
            AND ava_updated = '+'
          ORDER  BY ava_changed DESC)
        WHERE  ROWNUM <= 1;
      EXCEPTION
        WHEN no_data_found THEN NULL;
      END;
      
      IF vnewvalue ='25TP' AND voldvalue ='A'
        AND NVL(evt.evt_reopened, '-') = '-' THEN
        /* count child MP */
        SELECT COUNT(1) INTO vmpchdchk FROM R5EVENTS e
        WHERE e.evt_parent = evt.evt_code
          AND NVL(e.evt_reopened,'-') = '-';
        /* manage MP with routes*/
        IF vmpchdchk > 0 AND evt.evt_route IS NOT NULL THEN
          FOR chd_wo IN chd_evt(evt.evt_code) LOOP
            UPDATE R5EVENTS
            SET evt_reopened ='+'
            WHERE evt_code = chd_wo.evt_code
              AND NVL(evt_reopened,'-') = '-';
          END LOOP;
        END IF;
        BEGIN
          /* update r5events set evt_status ='C', 
            evt_completed = sysdate where evt_code =  evt.evt_code */
          O7CREVT8(evt.evt_code, evt.evt_mp, evt.evt_mp_org, 
            evt.evt_mp_rev, evt.evt_object, evt.evt_object_org,
            NULL, vmeterdue, NULL, 0, NULL, voutwo, chk);
          SELECT * INTO evttwo FROM R5EVENTS WHERE evt_code = voutwo;
          IF evttwo.evt_status = 'A' THEN
            UPDATE R5EVENTS SET evt_printed = '-'
            WHERE evt_code = voutwo;
            UPDATE R5EVENTS SET evt_reopened ='+' 
            WHERE evt_rstatus !='A'
              AND evt_mp = evt.evt_mp
              AND evt_mp_org = evt.evt_mp_org
              AND evt_mp_rev = evt.evt_mp_rev
              AND evt_object = evt.evt_object
              AND evt_object_org = evt.evt_object_org
              AND NVL(evt_reopened,'-') = '-';
          ELSE NULL; 
          END IF; 
        EXCEPTION
          WHEN no_data_found THEN NULL; 
        END;
      END IF;
    END IF;
  END IF;
  /* release next WO Actual Close*/
  IF evt.evt_type IN ( 'PPM' )
    AND evt.evt_status = '50SO'
    AND NVL(evt.evt_reopened,'-') = '-'
    AND evt.evt_mp IS NOT NULL THEN
    /* clear any stray evts with evt_status = A */
    DELETE FROM R5EVENTS
    WHERE evt_org = evt.evt_org
      AND evt_object = evt.evt_object
      AND evt_object_org = evt.evt_object_org
      AND evt_mp IS NULL AND evt_mp_seq IS NOT NULL
      AND evt_ppm IS NULL AND evt_status = 'A';
    /* get awaitng count */
    SELECT COUNT(1) INTO  vawo FROM  R5EVENTS
    WHERE evt_org = evt.evt_org AND evt_object = evt.evt_object
      AND evt_object_org = evt.evt_object_org
      AND evt_mp = evt.evt_mp AND evt_mp_org = evt.evt_mp_org
      AND evt_mp_rev = evt.evt_mp_rev AND evt_status = 'A'
      AND evt_code <> evt.evt_code;
    /* skip if evt_status = A is already exist*/
    IF vawo > 0 THEN
      RETURN;
    END IF;
    /* count MP */
    SELECT COUNT(1) INTO vmpchk FROM R5MAINTENANCEPATTERNS m,
      R5PATTERNSEQUENCES p
    WHERE m.mtp_code = evt.evt_mp
      AND m.mtp_org = evt.evt_mp_org
      AND m.mtp_revision = evt.evt_mp_rev
      AND NVL(m.mtp_allowduplicatewo,'-') = '-'
      AND NVL(m.mtp_class,'*') != '*'
      AND ((m.mtp_class = 'CBMT'
        AND NVL(m.mtp_releasetype,'-') = '-')
        OR (m.mtp_class = 'MTCB' AND m.mtp_releasetype = 'AV')
        OR (m.mtp_class = 'MTAV' AND m.mtp_releasetype = 'AV')
        OR (m.mtp_class = 'MTAD' AND m.mtp_releasetype = 'AD')
        OR (m.mtp_class = 'MTED' AND m.mtp_releasetype = 'ED'))
      AND p.psq_mp_org = m.mtp_org
      AND p.psq_mp = m.mtp_code
      AND p.psq_revision = m.mtp_revision
      AND p.psq_sequence = evt.evt_mp_seq
      AND p.psq_pk = evt.evt_psqpk
      AND p.psq_seqtype = 'AC';
    /* MP exist*/
    IF vmpchk > 0 THEN
      /* count child MP */
      SELECT COUNT(1) INTO vmpchdchk FROM R5EVENTS e
      WHERE e.evt_parent = evt.evt_code
        AND NVL(e.evt_reopened,'-') = '-';
      /* manage MP with routes*/
      IF vmpchdchk > 0 AND evt.evt_route IS NOT NULL THEN
        FOR chd_wo IN chd_evt(evt.evt_code) LOOP
          UPDATE R5EVENTS
          SET evt_reopened ='+'
          WHERE evt_code = chd_wo.evt_code
            AND NVL(evt_reopened,'-') = '-';
        END LOOP;
      END IF;
      /* update r5events set evt_status ='C',
         evt_completed = sysdate where evt_code =  evt.evt_code */
      BEGIN
        O7CREVT8(evt.evt_code, evt.evt_mp, evt.evt_mp_org,
          evt.evt_mp_rev, evt.evt_object, evt.evt_object_org,
          NULL, vmeterdue, NULL, 0, NULL, voutwo, chk);
        SELECT * INTO evttwo FROM R5EVENTS WHERE evt_code = voutwo;
        IF evttwo.evt_status = 'A' THEN
          UPDATE R5EVENTS SET evt_printed = '-'
          WHERE evt_code = voutwo;
          UPDATE R5EVENTS SET evt_reopened ='+'
          WHERE evt_rstatus !='A'
            AND evt_mp = evt.evt_mp
            AND evt_mp_org = evt.evt_mp_org
            AND evt_mp_rev = evt.evt_mp_rev
            AND evt_object = evt.evt_object
            AND evt_object_org = evt.evt_object_org
            AND NVL(evt_reopened,'-') = '-';
        ELSE NULL;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN NULL;
      END;
    END IF;
  END IF;
  /* fix activities*/  
  IF evt.evt_status IN ('25TP','40PR') AND evt.evt_mp IS NOT NULL 
    AND NVL(evt.evt_printed,'-') != '-' THEN
    /* start date*/
    SELECT COUNT(1) INTO vevtactstr FROM R5ACTIVITIES
    WHERE act_event = evt.evt_code
      AND act_start != evt.evt_target;
    IF vevtactstr > 0 AND evt.evt_status = '25TP' THEN
      FOR act_st IN act_str(evt.evt_code,evt.evt_target) LOOP
        UPDATE R5ACTIVITIES
        SET act_start = evt.evt_target
        WHERE act_event = evt.evt_code
          AND act_act = act_st.act_act;
      END LOOP;
    END IF;
    /* skip checklist*/
    SELECT COUNT(1) INTO vactchk 
    FROM R5ACTIVITIES,R5TASKS,R5ACTCHECKLISTS
    WHERE act_event = evt.evt_code
      AND act_task != 'ZFLT-TP-CHK-OPS-0003'
      AND NVL(act_udfchkbox04, '-') = '+'
      AND tsk_code = act_task
      AND tsk_revision = act_taskrev
      AND tsk_class = 'ZFLT-CHK'
      AND ack_act = act_act
      AND ack_event = act_event
      AND ack_requiredtoclose = 'YES';
    IF vactchk > 0 THEN
      FOR act_ch IN act_chk(evt.evt_code) LOOP
        UPDATE R5ACTCHECKLISTS
        SET ack_requiredtoclose = 'NO'
        WHERE ack_code = act_ch.ack_code;
      END LOOP;
    END IF;
    /* meter reading*/
    SELECT COUNT(1) INTO vactrea 
    FROM R5ACTIVITIES,R5TASKS,R5ACTCHECKLISTS
    WHERE act_event = evt.evt_code
      AND act_task LIKE '%-OPS-%'
      AND tsk_code = act_task
      AND tsk_revision = act_taskrev
      AND tsk_class = 'ZFLT-CHK'
      AND ack_act = act_act
      AND ack_event = act_event;
    IF vactrea = 0 AND NVL(evt.evt_parent,'X') = 'X' THEN
      FOR act_re IN act_rea(evt.evt_code) LOOP
        UPDATE R5ACTIVITIES
        SET act_note = NULL, act_task = NULL
        WHERE act_event = evt.evt_code
          AND act_act = act_re.act_act;
      END LOOP;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN
    RAISE_APPLICATION_ERROR (-20003, imsg);
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR (-20003,
      'ERR/R5EVENTS/25/U/NoDataFound');
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR (-20003,
      'ERR/R5EVENTS/25/U/'||SUBSTR(SQLERRM, 1, 500));
END;