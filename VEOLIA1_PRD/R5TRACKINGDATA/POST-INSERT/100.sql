DECLARE
    c1      r5trackingdata % ROWTYPE;
    ierrmsg VARCHAR2(400);
    val_err EXCEPTION;
BEGIN
    SELECT *
    INTO   c1
    FROM   r5trackingdata
    WHERE  ROWID = :rowid;

    IF c1.tkd_trans = 'MPCH' THEN
      IF c1.tkd_promptdata1 IS NULL THEN
        ierrmsg := 'ack_code missing';

        RAISE val_err;
      END IF;

      IF c1.tkd_promptdata2 IS NULL THEN
        ierrmsg := 'ack_type missing';

        RAISE val_err;
      END IF;

      IF c1.tkd_promptdata2 NOT IN ( '01', '02', '03', '04', '09','13','14','15','OPCK') THEN                    
        ierrmsg := 'unsupported ack_type';
        RAISE val_err;
      END IF;

      IF c1.tkd_promptdata2 = '01' THEN
        UPDATE r5actchecklists
        SET    ack_completed = c1.tkd_promptdata3,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '02' THEN
        UPDATE r5actchecklists
        SET    ack_yes = c1.tkd_promptdata3,
               ack_no = c1.tkd_promptdata4,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '03' THEN
        UPDATE r5actchecklists
        SET    ack_finding = c1.tkd_promptdata3,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '04' THEN
        UPDATE r5actchecklists
        SET    ack_value = c1.tkd_promptdata3,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '09' THEN
        UPDATE r5actchecklists
        SET    ack_ok = c1.tkd_promptdata3,
               ack_adjusted = c1.tkd_promptdata4,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '13' THEN
        UPDATE r5actchecklists
        SET    ack_checklistdate = to_date(c1.tkd_promptdata3,'YYYY-MM-DD'),
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '14' THEN
        UPDATE r5actchecklists
        SET    ack_checklistdatetime = to_date(c1.tkd_promptdata3,'YYYY-MM-DD HH24:MI'),
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = '15' THEN
        UPDATE r5actchecklists
        SET    ack_freetext = c1.tkd_promptdata3,
               ack_not_applicable = c1.tkd_promptdata5,
               ack_notes = c1.tkd_promptdata6,
               ack_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ack_lastsaved = SYSDATE,
               ack_updated = O7gttime(ack_object_org)
        WHERE  ack_code = c1.tkd_promptdata1;
      END IF;

      IF c1.tkd_promptdata2 = 'OPCK' THEN
        UPDATE r5operatorchecklists
        SET    ock_createdby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ock_updatedby = nvl(c1.tkd_promptdata7,'MIGRATION'),
               ock_lastsaved = SYSDATE,
               ock_updated = SYSDATE
        WHERE  ock_code = c1.tkd_promptdata1;
      END IF;

      o7interface.Trkdel(c1.tkd_transid);
    END IF;
EXCEPTION
    WHEN no_data_found THEN
      NULL;
    WHEN val_err THEN
      Raise_application_error(-20003, ierrmsg);
    WHEN OTHERS THEN
      Raise_application_error(-20003,
      'Processing error in Flex/r5trackingdata/Insert/100/'
      || SQLCODE
      || SQLERRM);
END; 