DECLARE
  mtp   R5MAINTENANCEPATTERNS%ROWTYPE;
  err   EXCEPTION;
  imsg  VARCHAR2(400);

BEGIN
  SELECT * INTO mtp FROM R5MAINTENANCEPATTERNS
  WHERE ROWID = :rowid;
  
  IF nvl(mtp.mtp_udfchkbox04,'-') != '+' THEN
    UPDATE R5MAINTENANCEPATTERNS
    SET   mtp_udfchkbox04 = '+'
    WHERE mtp_org = mtp.mtp_org
      AND mtp_code = mtp.mtp_code
      AND mtp_revision = mtp.mtp_revision;
  END IF;

EXCEPTION
  WHEN err THEN
  RAISE_APPLICATION_ERROR (-20003, imsg);
  WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5MAINTENANCEPATTERNS/5/I/'||Substr(SQLERRM, 1, 500));
END;