/*
 ===================================================================================================
  FILE : veo_sftp_pu_ion_1000.sql      AUTHOR: Raghuram HRS     CREATION DATE: 19-Nov-2020
 ===================================================================================================
  Copyright (c); 2020  Infor Consulting Services
 ========================================================================
  Project : POC
 ===================================================================================================
  PURPOSE OF FILE
    Post-update flex on u5ionmonitor 
 ===================================================================================================
  CHANGE HISTORY
  001  23-Nov-2020  -  Raghuram HRS - #Creation 
 ===================================================================================================
 -	update the SFTP checkbox
*/
DECLARE
vEntity  U5IONMONITOR.ion_keyfld1%TYPE;
vWorkOrder  U5IONMONITOR.ion_keyfld2%TYPE;
vDocCode  U5IONMONITOR.ion_keyfld3%TYPE;
vOrg  U5IONMONITOR.ion_keyfld4%TYPE;
vStatus  U5IONMONITOR.ion_keyfld5%TYPE;
vECount INTEGER;
vDcount INTEGER;

BEGIN
  begin
  SELECT NVL(ion_keyfld2,'X'), ion_keyfld3, ion_keyfld4,ion_keyfld5, ion_keyfld1
  INTO vWorkOrder, vDocCode, vOrg, vStatus, vEntity
  FROM u5ionmonitor 
  WHERE ROWID = :ROWID AND ion_keyfld5 = 'Completed' 
  AND ion_trans='DOC' AND ion_source='EAM'
  AND ion_destination='SFTP' AND ion_keyfld1='EVNT';
  EXCEPTION WHEN NO_DATA_FOUND THEN
    vWorkOrder := 'X';
  END;--2
  
  IF vWorkOrder<>'X'  THEN
    BEGIN
      SELECT COUNT(dae_document) INTO vDcount
      FROM r5docentities 
      WHERE dae_rentity = vEntity AND dae_entity=vEntity 
      AND dae_code=vWorkOrder;
      
      SELECT COUNT(ion_keyfld2) INTO vECount
      FROM u5ionmonitor 
      WHERE ion_keyfld2 = vWorkOrder AND ion_keyfld1=vEntity 
	  AND ion_keyfld5='Completed' AND ion_trans='DOC' AND ion_source='EAM'
      AND ion_destination='SFTP';
      
      IF vDcount=vECount THEN
      BEGIN
        UPDATE r5events 
        SET evt_udfchkbox06='+'
        WHERE evt_code = vWorkOrder AND evt_org=vOrg;
      END;
      END IF;
    END;
  END IF;
END;