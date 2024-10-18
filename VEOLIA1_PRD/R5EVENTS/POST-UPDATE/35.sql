DECLARE
  evt           r5events%ROWTYPE;
  vlw           r5events%ROWTYPE;
  visupddue     r5events.evt_meterinterval%TYPE;
  vsumint       NUMBER;
  vokstart      DATE;
  vnextwo       r5events.evt_code%TYPE;
  vseqgap       NUMBER;
  vnewdue       DATE;
  vnewend       DATE;
  err           EXCEPTION;
  imsg          VARCHAR2(1000);
  CURSOR cur_nextevt (vnextwo VARCHAR2) IS
    SELECT mtp_releasetype, mtp_releasetype2, mtp_code,
      mtp_org, mtp_revision, peq_dormstart, peq_dormend,
      peq_dormreuse, psq_okwindow, psq_nearwindow,
      psq_genwindow, psq_seqtype, psq_freq, psq_perioduom,
      evt_code, evt_meterdue, evt_meterdue2, evt_due,
      evt_org, evt_standwork, evt_metuom, evt_metuom2,
      evt_object, evt_object_org, evt_meterduedate,
      evt_meterduedate2, evt_meterinterval,
      evt_meterinterval2, evt_freq, evt_perioduom,
      evt_target, evt_duration
    FROM R5MAINTENANCEPATTERNS, R5PATTERNEQUIPMENT,
      R5PATTERNSEQUENCES, R5EVENTS
    WHERE mtp_org = evt_mp_org AND mtp_code = evt_mp
      AND mtp_revision = evt_mp_rev
      AND peq_mp_org = evt_mp_org AND peq_mp = evt_mp
      AND peq_revision = evt_mp_rev
      AND peq_object_org = evt_object_org
      AND peq_object = evt_object
      AND psq_mp_org = evt_mp_org AND psq_mp = evt_mp
      AND psq_revision = evt_mp_rev
      AND psq_pk = evt_psqpk
      AND psq_sequence = evt_mp_seq AND evt_rstatus = 'A'
      AND evt_code = vnextwo AND evt_mp IS NOT NULL;

BEGIN
  SELECT * INTO evt FROM R5EVENTS WHERE ROWID = :rowid;
  
  IF evt.evt_type ='PPM' AND evt.evt_mp IS NOT NULL
    AND evt.evt_freq IS NOT NULL
    AND evt.evt_perioduom IS NOT NULL
    AND evt.evt_meterinterval IS NOT NULL
    AND evt.evt_completed IS NOT NULL
    AND evt.evt_status IN ('50SO', '55CA', 'C') THEN
    SELECT COUNT(1) INTO visupddue
    FROM R5MAINTENANCEPATTERNS mtp,
      R5PATTERNSEQUENCES psq
    WHERE mtp.mtp_org = evt.evt_mp_org
      AND mtp.mtp_code = evt.evt_mp
      AND mtp.mtp_revision = evt.evt_mp_rev
      AND mtp.mtp_releasetype = 'AV'
      AND mtp.mtp_class = 'MTCB'
      AND psq.psq_mp_org = mtp.mtp_org
      AND psq.psq_mp = mtp.mtp_code
      AND psq.psq_revision = mtp.mtp_revision
      AND psq.psq_sequence = evt.evt_mp_seq
      AND psq.psq_pk = evt.evt_psqpk
      AND psq.psq_seqtype = 'D'
      AND psq.psq_freq IS NOT NULL
      AND psq.psq_meter IS NOT NULL
      AND evt.evt_due IS NOT NULL;
    
    IF visupddue > 0 THEN
      BEGIN
      /* retrieve next WO */
        SELECT evt_code INTO vnextwo
        FROM (SELECT e.evt_code FROM R5EVENTS e
          WHERE e.evt_mp_org = evt.evt_mp_org
            AND e.evt_mp = evt.evt_mp
            AND e.evt_mp_rev = evt.evt_mp_rev
            AND e.evt_object_org = evt.evt_object_org
            AND e.evt_object = evt.evt_object
            AND e.evt_rstatus = 'A'
          ORDER BY e.evt_code)
        WHERE ROWNUM <= 1;
        /* get next wo MP freq */
        FOR i IN cur_nextevt(vnextwo) LOOP
          /* find last completed WO exclude REJ & CANC */
          SELECT * INTO vlw FROM R5EVENTS
          WHERE evt_code = (SELECT max(e.evt_code)
            FROM R5EVENTS e
            WHERE e.evt_mp_org = evt.evt_mp_org
              AND e.evt_mp = evt.evt_mp
              AND e.evt_mp_rev = evt.evt_mp_rev
              AND e.evt_object_org = evt.evt_object_org
              AND e.evt_object = evt.evt_object
              AND e.evt_status IN ( '50SO', '55CA', 'C')
              AND e.evt_completed IS NOT NULL);

          SELECT SUM(evt_meterinterval) INTO vsumint
          FROM R5EVENTS e
          WHERE e.evt_mp_org = evt.evt_mp_org
            AND e.evt_mp = evt.evt_mp
            AND e.evt_mp_rev = evt.evt_mp_rev
            AND e.evt_object_org = evt.evt_object_org
            AND e.evt_object = evt.evt_object
            AND TO_NUMBER(e.evt_code) > TO_NUMBER(vlw.evt_code);
          
          IF (vsumint + vlw.evt_meterdue) = i.evt_meterdue THEN
            vokstart := TRUNC(vlw.evt_completed);
            vseqgap := (i.evt_meterdue - vlw.evt_meterdue)
              / i.evt_meterinterval;
            vnewdue := vokstart + O7GTFREQ(i.evt_freq * vseqgap,
              i.evt_perioduom, vokstart);
            vnewend := vnewdue + i.evt_duration - 1;
            
            UPDATE R5EVENTS
            SET evt_due = vnewdue,
              evt_target = vnewdue,
              evt_requeststart = NULL,
              evt_schedend = vnewend,
              evt_requestend = NULL
            WHERE  evt_code = vnextwo
              AND (evt_due <> vnewdue OR evt_target <> vnewdue);
            
            UPDATE R5ACTIVITIES
            SET act_start = vnewdue
            WHERE  act_event = vnextwo
            AND    (act_start is null or act_start <> vnewdue);
          END IF;
        END LOOP;
      EXCEPTION
        WHEN no_data_found THEN NULL;
      END;
    END IF; --vIsUpdDue > 0
  END IF;
EXCEPTION
  WHEN err THEN
    RAISE_APPLICATION_ERROR (-20003, imsg);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR (-20003,
      'ERR/R5EVENTS/35/U/'||SUBSTR(SQLERRM, 1, 500));
END; 