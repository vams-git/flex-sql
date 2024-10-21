DECLARE
  peq   R5PATTERNEQUIPMENT%ROWTYPE;
  aceq  NUMBER;
  inac  VARCHAR2(1);
  err   EXCEPTION;
  imsg  VARCHAR2(400);

BEGIN
  SELECT * INTO peq FROM R5PATTERNEQUIPMENT
  WHERE ROWID = :rowid;
  
  SELECT COUNT(1) INTO aceq FROM R5PATTERNEQUIPMENT
  WHERE peq_mp_org = peq.peq_mp_org
    AND peq_mp = peq.peq_mp
    AND peq_revision = peq.peq_revision
    AND (peq_object_org||'#'||peq_object
      != peq.peq_object_org||'#'||peq.peq_object)
    AND peq_status != 'I';

  inac := '-';

  IF aceq = 0 AND peq.peq_status = 'I' THEN
    inac := '+';
  END IF;
  
  UPDATE R5MAINTENANCEPATTERNS
  SET mtp_udfchkbox04 = inac,
    mtp_udfchar02 = NULL,
    mtp_udfchar04 = NULL,
    mtp_udfchar05 = NULL
  WHERE mtp_org = peq.peq_mp_org
    AND mtp_code = peq.peq_mp
    AND mtp_revision = peq.peq_revision;

EXCEPTION
  WHEN err THEN
  RAISE_APPLICATION_ERROR (-20003, imsg);
  WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR (-20003,
    'ERR/R5PATTERNEQUIPMENT/20/U/'||Substr(SQLERRM, 1, 500));
END;