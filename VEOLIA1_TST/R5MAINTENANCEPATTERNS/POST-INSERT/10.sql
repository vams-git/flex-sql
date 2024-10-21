DECLARE
  mtp   r5maintenancepatterns%ROWTYPE;
  mtyp  r5maintenancepatterns.mtp_releasetype%TYPE;
  rtyp  r5maintenancepatterns.mtp_releasetype%TYPE;
  mcls  r5maintenancepatterns.mtp_class%TYPE;
  muom  r5maintenancepatterns.mtp_metuom%TYPE;
  ruom  r5maintenancepatterns.mtp_metuom%TYPE;
  err   EXCEPTION;
  imsg  VARCHAR2(400);

BEGIN
  SELECT * INTO mtp FROM R5MAINTENANCEPATTERNS
  WHERE ROWID = :rowid;
  mtyp := mtp.mtp_releasetype;
  mcls := mtp.mtp_class;
  muom := mtp.mtp_metuom;

  IF NVL(mcls,'*') != '*' THEN
    IF mcls LIKE 'MT%' AND NVL(muom,'-') = '-' THEN
      imsg := 'Meter UOM cannot be null';
      RAISE err;
    END IF;

    IF (mcls = 'MTCB' AND NVL(mtyp,'-') != 'AV')
      OR (mcls = 'MTED' AND NVL(mtyp,'-') != 'ED')
      OR (mcls = 'MTAD' AND NVL(mtyp,'-') != 'AD')
      OR (mcls = 'MTAV' AND NVL(mtyp,'-') != 'AV')
      OR (mcls = 'CBMT' AND NVL(mtyp,'-') != '-') THEN
      
      rtyp := NULL;
      ruom := NULL;
      
      IF mcls = 'MTCB' AND NVL(mtyp,'-') != 'AV' THEN
        rtyp := 'AV';
        ruom := muom;
      END IF;
      IF mcls = 'MTED' AND NVL(mtyp,'-') != 'ED' THEN
        rtyp := 'ED';
        ruom := muom;
      END IF;
      IF mcls = 'MTAD' AND NVL(mtyp,'-') != 'AD' THEN
        rtyp := 'AD';
        ruom := muom;
      END IF;
      IF mcls = 'MTAV' AND NVL(mtyp,'-') != 'AV' THEN
        rtyp := 'AV';
        ruom := muom;
      END IF;

      UPDATE r5maintenancepatterns
      SET mtp_releasetype = rtyp,
        mtp_metuom = ruom
      WHERE ROWID = :rowid;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN
    Raise_application_error (-20003, imsg);
  WHEN no_data_found THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/10/Insert/NoDataFound');
  WHEN OTHERS THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/10/I'||Substr(SQLERRM, 1, 500));
END; 