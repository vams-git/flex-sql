DECLARE
  mtp   r5maintenancepatterns%ROWTYPE;
  mtyp  r5maintenancepatterns.mtp_releasetype%TYPE;
  rtyp  r5maintenancepatterns.mtp_releasetype%TYPE;
  mcls  r5maintenancepatterns.mtp_class%TYPE;
  muom  r5maintenancepatterns.mtp_metuom%TYPE;
  ruom  r5maintenancepatterns.mtp_metuom%TYPE;
  aftertyp  VARCHAR2(1);
  befortyp  VARCHAR2(1);
  cwo   NUMBER;
  aceq   NUMBER;
  acsq   NUMBER;
  acwo   NUMBER;
  peq   r5patternequipment%ROWTYPE;
  vnewvalue     r5audvalues.ava_to%TYPE;
  voldvalue     r5audvalues.ava_from%TYPE;
  vtimediff     NUMBER;
  err   EXCEPTION;
  imsg  VARCHAR2(400);
BEGIN
  SELECT * INTO mtp FROM R5MAINTENANCEPATTERNS
  WHERE ROWID = :rowid;
  mtyp := mtp.mtp_releasetype;
  mcls := mtp.mtp_class;
  muom := mtp.mtp_metuom;
  
  BEGIN
    SELECT ava_to, ava_from, timediff
    INTO vnewvalue, voldvalue, vtimediff
    FROM (SELECT ava_to, ava_from,
      ABS(SYSDATE - ava_changed) * 24 * 60 * 60 AS timediff
      FROM R5AUDVALUES, R5AUDATTRIBS
      WHERE ava_table = aat_table
        AND ava_attribute = aat_code
        AND aat_table = 'R5MAINTENANCEPATTERNS'
        AND aat_column IN ('MTP_CLASS')
        AND ava_table = 'R5MAINTENANCEPATTERNS'
        AND ava_primaryid = mtp.mtp_code
        AND ava_updated = '+'
      ORDER  BY ava_changed DESC)
    WHERE  ROWNUM <= 1;
  EXCEPTION
    WHEN no_data_found THEN NULL;
  END;

  IF (NVL(vnewvalue,'X') != NVL(voldvalue,'Y') AND vtimediff = 0) THEN

    IF NVL(vnewvalue,'X') = 'X' AND NVL(mtp.mtp_releasetype,'X') = 'X' THEN
      aftertyp := 'C';
    ELSE
      aftertyp := 'M';
    END IF;

    IF NVL(vnewvalue,'X') != 'X' AND SUBSTR(vnewvalue, 1,2) = 'MT' THEN
      aftertyp := 'M';
    ELSE
      aftertyp := 'C';
    END IF;

    IF NVL(voldvalue,'Y') = 'Y' AND NVL(mtp.mtp_releasetype,'Y') = 'Y' THEN
      befortyp := 'C';
    ELSE
      befortyp := 'M';
    END IF;

    IF NVL(voldvalue,'Y') != 'Y' AND SUBSTR(voldvalue, 1,2) = 'MT' THEN
      befortyp := 'M';
    ELSE
      befortyp := 'C';
    END IF;
    
    -- check work order
    SELECT COUNT(1) INTO cwo FROM R5PATTERNSEQUENCES,R5EVENTS
    WHERE psq_mp_org = mtp.mtp_org
      AND psq_mp = mtp.mtp_code
      AND psq_revision = mtp.mtp_revision
      AND evt_psqpk = psq_pk;
    IF cwo != 0 AND aftertyp != befortyp THEN
      imsg := 'Work Order record(s) related to MP exist. Unable to change MP from ';
      IF befortyp = 'M' THEN
        imsg := imsg || 'meter to calender based type';
      ELSE
        imsg := imsg || 'calendar to meter based type';
      END IF;
      RAISE err;
    END IF;

    -- check existing sequence
    SELECT COUNT(1) INTO acsq FROM R5PATTERNSEQUENCES
    WHERE psq_mp_org = mtp.mtp_org
      AND psq_mp = mtp.mtp_code
      AND psq_revision = mtp.mtp_revision
      AND NVL(psq_notused,'-') = '-';
    IF acsq != 0 THEN
      imsg := 'asccociated sequence(s)';
    END IF;

    -- check active equipment
    SELECT COUNT(1) INTO aceq FROM R5PATTERNEQUIPMENT
    WHERE peq_mp_org = mtp.mtp_org
      AND peq_mp = mtp.mtp_code
      AND peq_revision = mtp.mtp_revision
      AND peq_status != 'I';
    IF aceq != 0 THEN
      IF imsg IS NOT NULL THEN
        imsg := imsg || 'and active equipment(s)';
      ELSE
        imsg := 'active equipment(s)';
      END IF;
    END IF;

    IF imsg IS NOT NULL THEN
      imsg := 'Unable to change MP class. There are ' || imsg || ' related to the MP.';
      RAISE err;
    END IF;

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
  END IF;

EXCEPTION
  WHEN err THEN
    Raise_application_error (-20003, imsg);
  WHEN no_data_found THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/10/Update/NoDataFound');
  WHEN OTHERS THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/10/U'||Substr(SQLERRM, 1, 500));
END; 