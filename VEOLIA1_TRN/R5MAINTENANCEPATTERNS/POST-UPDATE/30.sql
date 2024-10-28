DECLARE
  mtp           R5MAINTENANCEPATTERNS%ROWTYPE;
  ceq           NUMBER;
  cwo           NUMBER;
  csq           NUMBER;
  chk           VARCHAR2(3);
  vpsqpk        R5PATTERNSEQUENCES.psq_pk%TYPE;
  vpsqpseq      R5PATTERNSEQUENCES.psq_sequence%TYPE;
  vpsqtype      R5PATTERNSEQUENCES.psq_seqtype%TYPE;
  vpsqfreq      R5PATTERNSEQUENCES.psq_freq%TYPE;
  vpsqperioduom R5PATTERNSEQUENCES.psq_perioduom%TYPE;
  vpsqmeter     R5PATTERNSEQUENCES.psq_meter%TYPE;
  vpsqmeter2    R5PATTERNSEQUENCES.psq_meter2%TYPE;
  vpsqgen       R5PATTERNSEQUENCES.psq_genwindow%TYPE;
  err           EXCEPTION;
  imsg          VARCHAR2(400);
  CURSOR cpsq(vmporg VARCHAR2, vmp VARCHAR2,
    vmprev NUMBER, vst VARCHAR2) IS
    SELECT psq_pk, psq_sequence, psq_standwork,
      psq_wodesc, psq_seqtype, psq_freq,
      psq_perioduom, psq_meter, psq_meter2
    FROM R5PATTERNSEQUENCES
    WHERE psq_mp_org = vmporg
      AND psq_mp = vmp
      AND psq_revision = vmprev
      AND (nvl(psq_notused,'-') = '-'
        OR nvl(psq_notused,'-') = vst)
    ORDER BY psq_sequence ASC;

BEGIN
  SELECT * INTO mtp FROM R5MAINTENANCEPATTERNS
  WHERE ROWID = :rowid;

  IF mtp.mtp_udfchar02 IN ('CLMP','CPMP') THEN
    -- check mp have active equipment
    SELECT Count(1) INTO ceq FROM R5PATTERNEQUIPMENT
    WHERE peq_mp_org = mtp.mtp_org
      AND peq_mp = mtp.mtp_code
      AND peq_revision = mtp.mtp_revision
      AND peq_status = 'A';
    -- return if any
    IF ceq > 0 THEN
      imsg := 'There an active plan for this MP';
      RAISE err;
    END IF;

    -- clear mp sequence
    IF mtp.mtp_udfchar02 = 'CLMP' THEN
      FOR rec_psq IN
        cpsq(mtp.mtp_org, mtp.mtp_code,
          mtp.mtp_revision,'+') LOOP
        -- check if WO is referencing mp sequence
        SELECT Count(1)
        INTO  cwo
        FROM  R5EVENTS
        WHERE evt_mp_org = mtp.mtp_org
          AND evt_mp = mtp.mtp_code
          AND evt_mp_rev = mtp.mtp_revision
          AND evt_psqpk = rec_psq.psq_pk;
        -- mark inactive if yes
        IF cwo > 0 THEN
          UPDATE R5PATTERNSEQUENCES
          SET psq_notused = '+'
          WHERE psq_mp_org = mtp.mtp_org
            AND psq_mp = mtp.mtp_code
            AND psq_revision = mtp.mtp_revision
            AND psq_sequence = rec_psq.psq_sequence;
        END IF;
        -- delete if not
        IF cwo = 0 THEN
          DELETE R5PATTERNSEQUENCES
          WHERE psq_mp_org = mtp.mtp_org
            AND psq_mp = mtp.mtp_code
            AND psq_revision = mtp.mtp_revision
            AND psq_pk = rec_psq.psq_pk
            AND psq_sequence = rec_psq.psq_sequence;
        END IF;
      END LOOP;
      -- clean up triggering condition
      UPDATE R5MAINTENANCEPATTERNS
      SET mtp_udfchar02 = NULL
      WHERE ROWID = :rowid;
    END IF;

    -- copy mp sequence
    IF mtp.mtp_udfchar02 = 'CPMP' THEN
      -- check if there's existing sequence on mp
      SELECT Count(1)
      INTO  csq
      FROM  R5PATTERNSEQUENCES
      WHERE psq_mp_org = mtp.mtp_org
        AND psq_mp = mtp.mtp_code
        AND psq_revision = mtp.mtp_revision
        AND nvl(psq_notused,'-') = '-';
      -- return if any
      IF csq > 0 THEN
        imsg := 'There an existing sequence for this MP';
        RAISE err;
      END IF;
      -- check if source mp is populated
      IF nvl(mtp.mtp_udfchar03,'X') = 'X' THEN
        imsg := 'MP Sequence Source is missing';
        RAISE err;
      END IF;
      -- initialise sequence number
      vpsqpseq := 0;         
      -- for each sequence in copied mp
      FOR rec_psq IN
        cpsq(mtp.mtp_org, mtp.mtp_udfchar03,
          mtp.mtp_revision,'-') LOOP
        -- prep sequence formatting for new mp
        -- duplicate type
        IF nvl(mtp.mtp_allowduplicatewo,'-') = '+' THEN
          vpsqtype := NULL;
          vpsqfreq := rec_psq.psq_freq;
          vpsqperioduom := rec_psq.psq_perioduom;
          vpsqmeter := NULL;
          vpsqmeter2 := NULL;
          vpsqgen := NULL;
        END IF;
        -- non-duplicate type
        IF nvl(mtp.mtp_metuom,'-') = '-' 
          AND nvl(mtp.mtp_metuom2,'-') = '-'
          AND nvl(mtp.mtp_allowduplicatewo,'-') = '-' THEN
          vpsqtype := rec_psq.psq_seqtype;
          vpsqfreq := rec_psq.psq_freq;
          vpsqperioduom := rec_psq.psq_perioduom;
          vpsqmeter := NULL;
          vpsqmeter2 := NULL;
          vpsqgen := 100;
        END IF;
        -- non-duplicate type with meters
        IF ( nvl(mtp.mtp_metuom,'-') != '-' 
          OR nvl(mtp.mtp_metuom2,'-') != '-' )
          AND nvl(mtp.mtp_allowduplicatewo,'-') = '-' THEN
          vpsqtype := rec_psq.psq_seqtype;
          vpsqmeter := rec_psq.psq_meter;
          vpsqmeter2 := rec_psq.psq_meter2;
          vpsqgen := 100;
          vpsqfreq := NULL;
          vpsqperioduom := NULL;
          IF nvl(mtp.mtp_class,'*') = 'MTCB' THEN
            vpsqfreq := rec_psq.psq_freq;
            vpsqperioduom := rec_psq.psq_perioduom;
          END IF;
        END IF;

        -- generate new pk
        r5o7.o7maxseq(vpsqpk, 'PPO', '1', chk );
        -- generate new sequence
        vpsqpseq := vpsqpseq + 10;

        -- insert sequence into new mp
        INSERT
        INTO R5PATTERNSEQUENCES
          (psq_pk, psq_mp_org, psq_mp, psq_revision, psq_sequence, 
            psq_standwork, psq_wodesc, psq_seqtype, psq_freq,
            psq_perioduom, psq_meter, psq_meter2, psq_okwindow,
            psq_nearwindow, psq_genwindow, psq_notused)
        VALUES
          (vpsqpk, mtp.mtp_org, mtp.mtp_code, mtp.mtp_revision,
            vpsqpseq, rec_psq.psq_standwork,
            rec_psq.psq_wodesc, vpsqtype, vpsqfreq, vpsqperioduom,
            vpsqmeter, vpsqmeter2, NULL, NULL, vpsqgen, '-');
      END LOOP;
      -- clean up triggering condition
      UPDATE R5MAINTENANCEPATTERNS
      SET    mtp_udfchar02 = NULL,
             mtp_udfchar03 = NULL
      WHERE  ROWID = :rowid;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN
    Raise_application_error (-20003, imsg);
  WHEN no_data_found THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/30/U/NoDataFound');
  WHEN OTHERS THEN
    Raise_application_error (-20003,
      'ERR/R5MAINTENANCEPATTERNS/30/U'||Substr(SQLERRM, 1, 500));
END; 