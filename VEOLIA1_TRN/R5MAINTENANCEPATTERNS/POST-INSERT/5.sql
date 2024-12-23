DECLARE
  MTP   R5MAINTENANCEPATTERNS%ROWTYPE;
  VINAC R5MAINTENANCEPATTERNS.MTP_UDFCHKBOX04%TYPE;
  VRVST R5MAINTENANCEPATTERNS.MTP_UDFCHAR30%TYPE;
  VRVNM R5MAINTENANCEPATTERNS.MTP_UDFNUM05%TYPE;
  ERR EXCEPTION;
  IMSG  VARCHAR2(400);
BEGIN
  SELECT * INTO MTP FROM R5MAINTENANCEPATTERNS
  WHERE ROWID = :ROWID;

  VINAC := '-';
  VRVST := 'U';
  VRVNM := MTP.MTP_REVISION;
  
  UPDATE R5MAINTENANCEPATTERNS
  SET MTP_UDFCHKBOX04 = VINAC,
    MTP_UDFCHAR30 = VRVST,
    MTP_UDFNUM05 = VRVNM
  WHERE MTP_ORG = MTP.MTP_ORG
    AND MTP_CODE = MTP.MTP_CODE
    AND MTP_REVISION = MTP.MTP_REVISION;

EXCEPTION
  WHEN ERR THEN RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5MAINTENANCEPATTERNS/5/I - '||IMSG);
  WHEN OTHERS THEN RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5MAINTENANCEPATTERNS/5/I - '||SUBSTR(SQLERRM, 1, 500));
END;