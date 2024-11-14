DECLARE
  obj   R5OBJECTS%ROWTYPE;
  uco   R5UCODES%ROWTYPE;
  v_ecfc_array SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
  v_uco NUMBER;
  ecf   U5U5ECFCOB%ROWTYPE;
  v_ecf NUMBER;
  err   EXCEPTION;
  imsg  VARCHAR2(400);

BEGIN
  SELECT * INTO obj FROM R5OBJECTS
  WHERE ROWID = :rowid;

  IF obj.obj_obrtype = 'A' THEN
    IF NVL(obj.obj_checklistfilter,'X') != 'X' THEN
      SELECT REGEXP_SUBSTR(obj.obj_checklistfilter, '[^,]+', 1, LEVEL)
        BULK COLLECT INTO v_ecfc_array FROM DUAL
      CONNECT BY REGEXP_SUBSTR(obj.obj_checklistfilter, '[^,]+', 1, LEVEL)
        IS NOT NULL;
      FOR i IN 1..v_ecfc_array.COUNT LOOP
        BEGIN
          SELECT * INTO uco FROM R5UCODES
          WHERE uco_entity = 'ECFC' AND uco_code = v_ecfc_array(i);
          v_uco := 1;
        EXCEPTION
          WHEN no_data_found THEN v_uco := 0;
        END;
        IF v_uco != 0 THEN
          BEGIN
            SELECT * INTO ecf FROM U5U5ECFCOB
            WHERE ecf_object_org = obj.obj_org AND ecf_object = obj.obj_code
              AND ecf_code = uco.uco_code;
            v_ecf := 1;
          EXCEPTION
            WHEN no_data_found THEN v_ecf := 0;
          END;
          IF v_ecf = 0 THEN
            INSERT INTO U5U5ECFCOB 
              (ECF_OBJECT_ORG, ECF_OBJECT, ECF_CODE, ECF_DESC,
                ECF_NOTUSED, CREATEDBY, CREATED, UPDATECOUNT)
              VALUES 
              (obj.obj_org, obj.obj_code, uco.uco_code, uco.uco_desc,
                '-', o7sess.cur_user, SYSDATE, 0);
          ELSIF NVL(ecf.ecf_notused,'-') != '-' THEN
            UPDATE U5U5ECFCOB
            SET ecf_notused = '-',
              UPDATEDBY = o7sess.cur_user,
              UPDATED = SYSDATE
            WHERE ecf_object_org = obj.obj_org AND ecf_object = obj.obj_code
              AND ecf_code = uco.uco_code;
          END IF;
        END IF;
      END LOOP;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN
  RAISE_APPLICATION_ERROR (-20003, 'ERR/R5OBJECTS/15/U - '||imsg);
  WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5OBJECTS/15/U - '||Substr(SQLERRM, 1, 500));
END;