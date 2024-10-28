/*
 ===================================================================================================
  FILE : veo_sftp_pu_evt_1000.sql      AUTHOR: Raghuram HRS     CREATION DATE: 19-Nov-2020
 ===================================================================================================
  Copyright (c); 2020  Infor Consulting Services
 ========================================================================
  Project : POC
 ===================================================================================================
  PURPOSE OF FILE
    Post-update flex on R5EVENTS 
 ===================================================================================================
  CHANGE HISTORY
  001  19-Nov-2020  -  Raghuram HRS - #Creation 
  002  01-Mar-2021  -  Raghuram HRS - EVT_UDFCHAR20 is not equal to “R”
 ===================================================================================================
 -  EVT_UDFCHAR24 change from “TBINV” to “CLAIMV”
@Charlene Xu: As we don’t have the track of old values on Cloud, can we consider the value as CLAIMV?
-  EVT_UDFCHAR20 is equal to “R”
-  EVT_UDFCHAR28 is not blank
-  EVT_SERVICEPROBLEM is not blank
-  EVT_JOBTYPE != MEC
Status ion_keyfld5 is record created 
ion_keyflddate1 created
*/
DECLARE
vEvtCode  r5events.evt_code%TYPE;
vEvtOrg   r5events.evt_org%TYPE;
vEvtUdfchar28   r5events.evt_udfchar28%TYPE;
vNewValue   r5events.evt_udfchar24%TYPE;
vOldValue   r5events.evt_udfchar24%TYPE;
chk           VARCHAR2(3);
vTransID      r5interface.int_transid%type;
BEGIN --1
  BEGIN --2
  SELECT NVL(evt_code,'X'), evt_org, TRANSLATE(REGEXP_REPLACE(evt_udfchar28,'[^a-z_A-Z_0-9_/]'),'/','_') 
  INTO vEvtCode, vEvtOrg, vEvtUdfchar28
  FROM r5events 
  WHERE ROWID = :ROWID AND EVT_JOBTYPE <> 'MEC'
  --AND NVL(EVT_SERVICEPROBLEM,'X')<>'X' 
  AND NVL(EVT_UDFCHAR28,'X')<>'X' 
  AND NVL(EVT_UDFCHAR20,'X')<>'R' 
  AND NVL(EVT_UDFCHAR24,'X')='CLAIMV' 
  AND NVL(EVT_UDFCHKBOX06,'-')<>'+'
  AND EVT_ORG IN ('QTN', 'STA');
  EXCEPTION WHEN NO_DATA_FOUND THEN
    vEvtCode := 'X';
  END;--2

  
  IF vEvtCode<>'X'  THEN -- 1IF
    BEGIN -- IF BEGIN
    
    BEGIN -- 1IF BEGIN
      SELECT c1,c2 INTO vNewValue, vOldValue 
          FROM (
          SELECT NVL(ava_to,'X') as c1, NVL(ava_from,'X') as c2
          FROM R5audvalues,r5audattribs
          WHERE ava_table = aat_table 
          AND ava_attribute = aat_code
          AND aat_table = 'R5EVENTS' 
          AND aat_column = 'EVT_UDFCHAR24'
          AND ava_table = 'R5EVENTS' 
          AND ava_primaryid = vEvtCode
          AND ava_updated = '+'
          ORDER by ava_changed DESC
          ) WHERE ROWNUM <= 1;
      EXCEPTION WHEN no_data_found THEN 
        vNewValue := 'X';
    END;
      
    IF vNewValue<>'X' AND vOldValue<>'X' AND vOldValue='TBINV' AND vNewValue='CLAIMV'  THEN  --2 IF 
    BEGIN --2 IF BEGIN
      FOR docRec IN(
      SELECT dae_document 
      FROM R5DOCENTITIES 
      WHERE dae_rentity = 'EVNT' and dae_entity='EVNT' and dae_code=vEvtCode
    ) LOOP
      BEGIN --3 LOOP BEGIN
      
      r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk); 
     
      INSERT INTO U5IONMONITOR(
       ion_create, ion_destination, ion_keyfld1,
       ion_keyfld2, ion_keyfld3, ion_keyfld4, ion_keyfld5,
       ion_keyflddate1, ion_keyflddate2, ion_message, ion_messageid,
       ion_ref, ion_req_wsmmsg, ion_retries, ion_rsp_wsmmsg,
       ion_sendemail, ion_source, ion_status, ion_trans,
       ion_transgroupid, ion_transid, ion_update, ion_variationid,
       ion_wsscode, ion_xmlseqno, updatecount,created, createdby
       ) VALUES(
        sysdate, 'SFTP', 'EVNT',
        vEvtCode, docRec.dae_document, vEvtOrg, 'New',
        sysdate, null, vEvtUdfchar28, null,
        null, null, null, null,
        null, 'EAM', 'New', 'DOC',
        null, vTransID, null, null,
        null, null,0, sysdate, O7SESS.cur_user
       );
      END; -- 3 LOOP BEGIN
      END LOOP;
    END; -- 2 IF BEGIN
    END IF; --2 IF
    END; --  IF BEGIN
  END IF; -- 1 IF
END;-- 1