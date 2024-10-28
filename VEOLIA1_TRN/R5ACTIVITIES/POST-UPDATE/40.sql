DECLARE
  act R5ACTIVITIES%ROWTYPE;
  evt R5EVENTS%ROWTYPE;
  vcount NUMBER;
  vclass VARCHAR2(80);
  vnewvalue R5AUDVALUES.ava_to%TYPE;
  voldvalue R5AUDVALUES.ava_from%TYPE;
  vtimediff NUMBER;
  ierrmsg VARCHAR2(800);
  err EXCEPTION;
BEGIN
  SELECT * INTO act FROM R5ACTIVITIES
  WHERE ROWID = :rowid;
  
  SELECT * INTO evt FROM R5EVENTS
  WHERE evt_code = act.act_event;
  
  IF evt.evt_status IN ('25TP', '40PR')
    AND evt.evt_mp IS NOT NULL
    AND evt.evt_meterdue IS NOT NULL
    AND evt.evt_metuom IS NOT NULL
    AND act.act_start != evt.evt_target THEN
    UPDATE R5ACTIVITIES
    SET act_start = evt.evt_target
    WHERE act_event = act.act_event
       AND act_act = act.act_act;
  END IF;

  IF NVL(act.act_task,'X') != 'X' THEN
    SELECT tsk_class INTO vclass FROM R5TASKS
    WHERE tsk_code = act.act_task
      AND tsk_revision = act.act_taskrev;
    
    SELECT COUNT(1) INTO vcount FROM R5ACTCHECKLISTS
    WHERE ack_event = act.act_event
      AND ack_act = act.act_act;
    
    IF vcount = 0 AND vclass IN ('ZFLT-CHK')
      AND act.act_task LIKE '%-OPS-%'
      AND NVL(evt.evt_parent,'X') = 'X' THEN
      UPDATE R5ACTIVITIES
      SET act_note = NULL, act_task = NULL
      WHERE act_event = act.act_event
        AND act_act = act.act_act;
    END IF;
      
    BEGIN
      SELECT ava_to, ava_from, timediff
      INTO vnewvalue, voldvalue, vtimediff
      FROM (
        SELECT ava_to, ava_from, 
          ABS(SYSDATE - ava_changed) * 24 * 60 * 60 AS timediff
        FROM R5AUDVALUES, R5AUDATTRIBS
        WHERE ava_table = aat_table
          AND ava_attribute = aat_code
          AND aat_table = 'R5ACTIVITIES'
          AND aat_column = 'ACT_UDFCHKBOX04'
          AND ava_table = 'R5ACTIVITIES'
          AND ava_primaryid = act.act_event
          AND ava_secondaryid = act.act_act
          AND ( ava_updated = '+' )
          AND ABS(SYSDATE - ava_changed) * 24 * 60 * 60 < 2
        ORDER  BY ava_changed DESC)
      WHERE  ROWNUM <= 1;
    EXCEPTION
      WHEN no_data_found THEN RETURN;
    END;
    
    IF vcount > 0 AND vclass IN ('ZFLT-CHK')
      AND act.act_task != 'ZFLT-TP-CHK-OPS-0003' THEN
      IF vnewvalue = '+' AND NVL(voldvalue,'-') = '-' THEN
        UPDATE R5ACTCHECKLISTS
        SET ack_requiredtoclose = 'NO'
        WHERE ack_event = act.act_event
          AND ack_act = act.act_act
          AND ack_requiredtoclose = 'YES';
      END IF;

      IF NVL(voldvalue,'-') = '-' AND voldvalue = '+' THEN
        UPDATE R5ACTCHECKLISTS
        SET ack_requiredtoclose = 'YES'
        WHERE ack_event = act.act_event
          AND ack_act = act.act_act
          AND ack_taskchecklistcode IN (
            SELECT tch_code FROM R5TASKCHECKLISTS
            WHERE  tch_task = act.act_task
              AND tch_taskrev = act.act_taskrev
              AND tch_requiredtoclose = 'YES');
      END IF;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5ACTIVITIES/40/UPDATE'||CHR(10)||ierrmsg);
  WHEN OTHERS THEN RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5ACTIVITIES/40/UPDATE'||CHR(10)||SUBSTR(SQLERRM,1,800));
END;