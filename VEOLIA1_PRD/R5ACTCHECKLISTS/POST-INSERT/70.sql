DECLARE
    ack       r5actchecklists%ROWTYPE;
    evt       r5events%ROWTYPE;
    wac       r5standwacts%ROWTYPE;
    act       r5activities%ROWTYPE;
    vtskclass r5tasks.tsk_class%TYPE;
    vtskrev   r5tasks.tsk_class%TYPE;
    vskip     r5activities.act_udfchkbox04%TYPE;
    vcnt      NUMBER;
    vnewvalue r5audvalues.ava_to%TYPE;
    voldvalue r5audvalues.ava_from%TYPE;
    vtimediff NUMBER;
    err EXCEPTION;
    imsg      VARCHAR2(1000);
BEGIN
    SELECT *
    INTO   ack
    FROM   R5ACTCHECKLISTS
    WHERE  ROWID = :rowid;
 -- skip if operator checklist
    IF NVL(ack.ack_rentity,'X') NOT IN ('OPCK','OPCL') THEN

    SELECT *
    INTO   evt
    FROM   R5EVENTS
    WHERE  evt_code = ack.ack_event;
 -- skip if not mp workorder
IF evt.evt_mp IS NOT NULL AND evt.evt_mp_org IS NOT NULL AND evt.evt_standwork IS NOT NULL THEN

      BEGIN
          SELECT ava_to,
                 ava_from,
                 timediff
          INTO   vnewvalue, voldvalue, vtimediff
          FROM   (SELECT ava_to,
                         ava_from,
                         ABS(SYSDATE - ava_changed) * 24 * 60 * 60 AS timediff
                  FROM   R5AUDVALUES,
                         R5AUDATTRIBS
                  WHERE  ava_table = aat_table
                     AND ava_attribute = aat_code
                     AND aat_table = 'R5EVENTS'
                     AND aat_column = 'EVT_STATUS'
                     AND ava_table = 'R5EVENTS'
                     AND ava_primaryid = evt.evt_code
                     AND ( ava_updated = '+' )
                     AND ABS(SYSDATE - ava_changed) * 24 * 60 * 60 < 2
                  ORDER  BY ava_changed DESC)
          WHERE  ROWNUM <= 1;
      EXCEPTION
          WHEN no_data_found THEN
            RETURN;
      END;

 -- skip if not just release wo
IF voldvalue = 'A' AND vnewvalue = '25TP' THEN

    SELECT *
    INTO   wac
    FROM   R5STANDWACTS
    WHERE  wac_standwork = evt.evt_standwork
       AND wac_act = ack.ack_act;

    SELECT NVL(tsk_class,'X')
    INTO   vtskclass
    FROM   R5TASKS
    WHERE  tsk_code = wac.wac_task;

    IF vtskclass IN ('ZFLT-CHK')
       AND wac.wac_task != 'ZFLT-TP-CHK-OPS-0003'
       AND NVL(wac.wac_udfchkbox04, '-') = '+'
       AND ack.ack_requiredtoclose = 'YES' THEN
      UPDATE R5ACTCHECKLISTS ack
      SET    ack.ack_requiredtoclose = 'NO'
      WHERE  ROWID = :rowid;
    END IF;
    END IF; -- skip if not just release wo
    END IF; -- skip if not mp workorder
    END IF; -- skip if operator checklist

EXCEPTION
    WHEN err THEN
      RAISE_APPLICATION_ERROR (-20003, imsg);
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR (SQLCODE, 'Error in Flex r5actchecklists/Post Insert/70/'
                                        ||SUBSTR(SQLERRM, 1, 500));
END; 