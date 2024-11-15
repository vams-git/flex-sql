DECLARE
  ecf   U5U5ECFCOB%ROWTYPE;
  v_checklistfilter   VARCHAR2(600);
  err   EXCEPTION;
  imsg  VARCHAR2(400);

BEGIN
  SELECT * INTO ecf FROM U5U5ECFCOB WHERE ROWID = :rowid;
  SELECT LISTAGG(ecf_code, ',') WITHIN GROUP (ORDER BY ecf_code)
    INTO v_checklistfilter FROM U5U5ECFCOB
  WHERE ecf_object_org = ecf.ecf_object_org AND ecf_object = ecf.ecf_object
    AND NVL(ecf_notused,'-') = '-';

  IF LENGTH(v_checklistfilter) > 500 THEN
    imsg := 'Maximum numbers of equipment filter for the equipment reached. Deactivate some to continue.';
    raise err;
  END IF;
  
  UPDATE R5OBJECTS SET obj_checklistfilter = v_checklistfilter
  WHERE obj_org = ecf.ecf_object_org AND obj_code = ecf.ecf_object;
EXCEPTION
  WHEN err THEN
  RAISE_APPLICATION_ERROR (-20003, 'ERR/U5U5ECFCOB/10/I - '||imsg);
  WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR (-20003,
    'ERR/U5U5ECFCOB/10/I - '||Substr(SQLERRM, 1, 500));
END;