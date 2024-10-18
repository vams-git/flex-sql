DECLARE
  evt           r5events%ROWTYPE;
  vmpcnt        NUMBER;
  err           EXCEPTION;
  imsg          VARCHAR2(400);
  CURSOR cur_evt(vmp VARCHAR,vob VARCHAR,voborg VARCHAR,
    vpk NUMBER,vcurrwo VARCHAR2) IS
    SELECT evt_code FROM R5EVENTS
    WHERE evt_mp = vmp AND evt_psqpk = vpk
      AND evt_object = vob
      AND evt_object_org = voborg
      AND evt_status = 'A' AND evt_code <> vcurrwo;

BEGIN
  SELECT * INTO evt FROM R5EVENTS WHERE ROWID = :rowid;
  /* remove duplicate evt_status = A */
  IF evt.evt_status = 'A' AND evt.evt_mp IS NOT NULL THEN
    /* count MP */
    SELECT COUNT(1) INTO vmpcnt
    FROM R5MAINTENANCEPATTERNS
    WHERE mtp_code = evt.evt_mp
      AND mtp_org = evt.evt_mp_org
      AND NVL(mtp_allowduplicatewo,'-') = '-'
      AND NVL(mtp_class,'*') != '*'
      AND ((mtp_class = 'CBMT' 
        AND NVL(mtp_releasetype,'-') = '-')
        OR (mtp_class = 'MTCB' AND mtp_releasetype = 'AV')
        OR (mtp_class = 'MTAV' AND mtp_releasetype = 'AV')
        OR (mtp_class = 'MTAD' AND mtp_releasetype = 'AD')
        OR (mtp_class = 'MTED' AND mtp_releasetype = 'ED'))
      AND EXISTS (SELECT 1 FROM R5PATTERNEQUIPMENT
        WHERE peq_mp = evt.evt_mp
          AND peq_mp_org = evt.evt_mp_org
          AND peq_object = evt.evt_object
          AND peq_object_org = evt.evt_object_org);
    
    IF vmpcnt > 0 THEN
      UPDATE R5EVENTS SET evt_printed = NULL
      WHERE  ROWID = :rowid;
      
      FOR rec_wo IN cur_evt(evt.evt_mp, evt.evt_object,
        evt.evt_object_org, evt.evt_psqpk, evt.evt_code) LOOP
        UPDATE R5EVENTS SET evt_mp = NULL
        WHERE ROWID = :rowid;
        
        UPDATE R5EVENTS
        SET evt_reopened = '-', evt_printed = NULL
        WHERE evt_code = rec_wo.evt_code
          AND NVL(evt_reopened,'-') = '+';
      END LOOP;
    END IF;
  END IF;
EXCEPTION
  WHEN err THEN
    RAISE_APPLICATION_ERROR (-20003, 'ERR/R5EVENTS/25/I - '||imsg);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR (-20003,
      'ERR/R5EVENTS/25/I - '||SUBSTR(SQLERRM, 1, 500));
END; 