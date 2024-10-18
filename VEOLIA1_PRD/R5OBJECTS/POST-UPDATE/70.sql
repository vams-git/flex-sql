DECLARE
  obj   R5OBJECTS%ROWTYPE;
  opeqnewvalue     R5AUDVALUES.ava_to%TYPE;
  opeqoldvalue     R5AUDVALUES.ava_from%TYPE;
  opeqtimediff     NUMBER;
  opeqlastchange     R5AUDVALUES.ava_changed%TYPE;
  cwo   NUMBER;
  err   EXCEPTION;
  imsg  VARCHAR2(400);
BEGIN
  SELECT * INTO obj FROM R5OBJECTS
  WHERE ROWID = :rowid;

  BEGIN
    SELECT ava_to, ava_from, timediff
    INTO opeqnewvalue, opeqoldvalue, opeqtimediff
    FROM (SELECT ava_to, ava_from,
      ABS(SYSDATE - ava_changed) * 24 * 60 * 60 AS timediff
      FROM R5AUDVALUES, R5AUDATTRIBS
      WHERE ava_table = aat_table
        AND ava_attribute = aat_code
        AND aat_table = 'R5OBJECTS'
        AND aat_column IN ('OBJ_OPERATIONALSTATUS')
        AND ava_table = 'R5OBJECTS'
        AND ava_primaryid = obj.obj_code
        AND ava_secondaryid = obj.obj_org
        AND ava_updated = '+'
      ORDER  BY ava_changed DESC)
    WHERE  ROWNUM <= 1;
  EXCEPTION
    WHEN no_data_found THEN NULL;
  END;
  
  -- check if 
  IF (NVL(opeqoldvalue,'X') = 'OUOF' AND NVL(opeqnewvalue,'Y') != 'OUOF' AND opeqtimediff = 0) THEN
    BEGIN
      SELECT ava_changed
      INTO opeqlastchange
      FROM (SELECT ava_changed
        FROM R5AUDVALUES, R5AUDATTRIBS
        WHERE ava_table = aat_table
          AND ava_attribute = aat_code
          AND aat_table = 'R5OBJECTS'
          AND aat_column IN ('OBJ_OPERATIONALSTATUS')
          AND ava_table = 'R5OBJECTS'
          AND ava_primaryid = obj.obj_code
          AND ava_secondaryid = obj.obj_org
          AND ava_updated = '+'
          AND ava_to = 'OUOF'
        ORDER  BY ava_changed DESC)
      WHERE  ROWNUM <= 1;
    EXCEPTION
      WHEN no_data_found THEN NULL;
    END;

    IF opeqlastchange IS NOT NULL THEN
      SELECT COUNT(1) INTO cwo FROM R5EVENTS,R5ACTIVITIES
      WHERE evt_object_org = obj.obj_org
        AND evt_object = obj.obj_code
        AND evt_status IN ('50SO','55CA','C')
        AND (evt_updated > opeqlastchange OR evt_created > opeqlastchange)
        AND act_event = evt_code
        AND act_task = 'ZFLT-TP-CHK-OPS-0003';
    ELSE
      SELECT COUNT(1) INTO cwo FROM R5EVENTS,R5ACTIVITIES
      WHERE evt_object_org = obj.obj_org
        AND evt_object = obj.obj_code
        AND evt_status IN ('50SO','55CA','C')
        AND act_event = evt_code
        AND act_task = 'ZFLT-TP-CHK-OPS-0003';
    END IF;

    IF cwo = 0 THEN
      imsg := 'Return to service work order is required';
      RAISE err;
    END IF;
  END IF;

EXCEPTION
  WHEN err THEN
    Raise_application_error (-20003, imsg);
  WHEN no_data_found THEN
    Raise_application_error (-20003,
      'ERR/R5OBJECTS/70/U/NoDataFound');
  WHEN OTHERS THEN
    Raise_application_error (-20003,
      'ERR/R5OBJECTS/70/U '||Substr(SQLERRM, 1, 500));
END; 