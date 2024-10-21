DECLARE
  ock   R5OPERATORCHECKLISTS%ROWTYPE;
  vTskClass   R5CLASSES.CLS_CODE%TYPE;
  obj   R5OBJECTS%ROWTYPE;
  vPosLastDVRDate   DATE;
  cflt    NUMBER;
  vAssignto   R5PERSONNEL.PER_CODE%TYPE;
  vDateTime   DATE;
  vDate   DATE;
  ceventno    R5EVENTS.EVT_CODE%TYPE;
  chk   VARCHAR2(3);
  vWODesc   R5EVENTS.EVT_DESC%TYPE;
  vUDFChar27    R5EVENTS.EVT_UDFCHAR27%TYPE;
  vComm   VARCHAR2(4000);
  fdoc    NUMBER;
  vOckUDF02   R5OPERATORCHECKLISTS.OCK_UDFCHAR02%TYPE;
  imsg    VARCHAR2(400);
  err    EXCEPTION;
  
  cursor cur_parent(vObj varchar2,vOrg varchar2) is 
   select obj_org,obj_code,obj_obtype,obj_udfdate04
  from 
  (select stc_parent_org,stc_parent,stc_parenttype,level
  ,ltrim(sys_connect_by_path(stc_child ,'/'),'/') path
  ,ltrim(sys_connect_by_path(stc.stc_childtype ,'/'),'/') typepath
  from  r5structures stc
  WHERE  stc_parenttype in ('07CP','06EQ','05FP')
  connect by  prior stc_parent = stc_child  AND prior stc_parent_org = stc_child_org
  start with stc_child =vObj and stc_child_org =vOrg),
  r5objects
  where obj_code = stc_parent and obj_org = stc_parent_org;
  
  CURSOR    c_faults(vOpCode VARCHAR2,vOrg VARCHAR2)
    IS SELECT ack_code,ack_desc,ack_notes
    FROM R5ACTCHECKLISTS
    WHERE ack_rentity = 'OPCK'
      AND ack_entitykey = vOpCode
      AND ack_entityorg = vOrg
      AND ack_reference = 'FAULTS'
      AND NVL(ack_completed,'-') = '+'
      AND ack_notes is not null
      ORDER BY ack_code;
  
  CURSOR    c_docs(vAckCode VARCHAR2)
    IS SELECT dae_document
    FROM R5DOCENTITIES
    WHERE dae_entity = 'OPCL'  
      AND dae_code = vAckCode;
      
BEGIN
  SELECT * INTO ock FROM R5OPERATORCHECKLISTS
  WHERE ROWID = :rowid;
  
  IF ock.ock_rstatus IN ('U','CC') THEN RETURN;
  END IF;
  
  SELECT tsk_class INTO vTskClass FROM R5TASKS
  WHERE tsk_code = ock.ock_task
    AND tsk_revision = ock.ock_taskrev;
  
  IF vTskClass ='ZFLT-CHK' THEN
    IF ock.ock_udfchar02 IS NOT NULL THEN RETURN;
    END IF;
    
    SELECT * INTO obj FROM R5OBJECTS
    WHERE obj_org = ock.ock_object_org
      AND obj_code = ock.ock_object;
    
    IF obj.obj_udfdate04 IS NULL
      OR obj.obj_udfdate04 < ock.ock_enddate THEN
      UPDATE R5OBJECTS
      SET obj_udfdate04 = ock.ock_enddate
      WHERE obj_code = ock.ock_object
        AND obj_org = ock.ock_object_org;
    END IF;
    
    if obj.obj_vehicle ='+' then
       for rec_parent in cur_parent(ock.ock_object,ock.ock_object_org) loop 
           if rec_parent.obj_udfdate04 is null or rec_parent.obj_udfdate04 < ock.ock_enddate then
              update r5objects 
              set    obj_udfdate04 = ock.ock_enddate
              where  obj_code = rec_parent.obj_code and obj_org = rec_parent.obj_org;
           end if;
       end loop;
    end if;
    
    /*IF obj.obj_obtype ='06EQ'
      AND obj.obj_vehicle ='+'
      AND obj.obj_position IS NOT NULL THEN
      
      SELECT obj_udfdate04 INTO vPosLastDVRDate
      FROM R5OBJECTS
      WHERE obj_code = obj.obj_position
        AND obj_org = obj.obj_position_org;
      
      IF vPosLastDVRDate IS NULL 
        OR vPosLastDVRDate < ock.ock_enddate THEN
        UPDATE R5OBJECTS
        SET obj_udfdate04 = ock.ock_enddate
        WHERE obj_code = obj.obj_position
          AND obj_org = obj.obj_position_org;
      END IF;
    END IF;*/

    SELECT COUNT(1) INTO cflt FROM R5ACTCHECKLISTS
    WHERE ack_rentity = 'OPCK'
      AND ack_entitykey = ock.ock_code
      AND ack_entityorg = ock.ock_org
      AND ack_reference = 'FAULTS'
      AND NVL(ack_completed,'-') = '+'
      AND ack_notes IS NOT NULL;

    IF cflt > 0 THEN
      BEGIN
        SELECT p.per_code INTO vAssignto
        FROM R5PERSONNEL p
        WHERE p.per_user = ock.ock_createdby;
      EXCEPTION
        WHEN no_data_found THEN vAssignto := NULL;
      END;
        
      vDateTime := o7gttime(ock.ock_org);
      vDate := trunc(o7gttime(ock.ock_org));
      
      FOR flt in c_faults(ock.ock_code,ock.ock_org) LOOP
        r5o7.o7maxseq(ceventno, 'EVENT', '1', chk);
        vWODesc := substr('DVR - ' || obj.obj_udfchar16
          || ' - ' || flt.ack_notes,1,80);
        vUDFChar27 := substr('DVR#' || ock.ock_code 
          || '_' || flt.ack_code ,1,80);
        
        INSERT INTO R5EVENTS
        ( EVT_ORG, EVT_CODE, EVT_TYPE, EVT_RTYPE,
          EVT_MRC, EVT_LTYPE, EVT_LOCATION,
          EVT_LOCATION_ORG, EVT_COSTCODE, EVT_PROJECT,
          EVT_PROJBUD, EVT_OBTYPE, EVT_OBJECT,
          EVT_OBJECT_ORG, EVT_ISSTYPE, EVT_FIXED,
          EVT_DATE, EVT_TARGET, EVT_SCHEDEND,
          EVT_DURATION, EVT_REPORTED, EVT_ENTEREDBY,
          EVT_CREATED, EVT_CREATEDBY, EVT_ORIGWO,
          EVT_ORIGACT, EVT_DESC, EVT_JOBTYPE,
          EVT_CLASS, EVT_CLASS_ORG, EVT_STATUS,
          EVT_PRIORITY, EVT_PERSON, EVT_ORIGIN,
          EVT_UDFCHAR27, EVT_UDFCHAR29, EVT_STANDWORK)
        VALUES
        ( ock.ock_org, ceventno, 'JOB', 'JOB',
          NVL(obj.obj_loaneddept,obj.obj_mrc) , obj.obj_ltype, obj.obj_location,
          obj.obj_location_org, obj.obj_costcode, null,
          null, obj.obj_obtype, obj.obj_code,
          obj.obj_org, 'F', 'V',
          vDateTime, vDate, vDate,
          1, vDateTime, ock.ock_createdby,
          vDateTime, ock.ock_createdby, null,
          null, vWODesc, 'RQ',
          'CO', '*', '15TV',
          null, null, vAssignto,
          vUDFChar27, NVL(obj.obj_loaneddept,obj.obj_mrc), null);

        o7creob1(ceventno, 'JOB', obj.obj_code, obj.obj_org,
          obj.obj_obtype, obj.obj_obrtype, chk);
          
        vComm := 'Fault ' || flt.ack_desc || '.' || chr(10)
          || 'Note: ' || flt.ack_notes;
        
        IF vComm IS NOT NULL THEN
          INSERT INTO R5ADDETAILS
          ( add_entity, add_rentity, add_type, add_rtype,
            add_code, add_lang, add_line, add_print,
            add_text, add_created, add_user)
          VALUES
          ( 'EVNT', 'EVNT', '*', '*',
            ceventno,'EN', 10, '+',
            vComm, vDateTime, ock.ock_createdby);
        END IF;
        
        SELECT COUNT(1) INTO fdoc FROM R5DOCENTITIES
        WHERE dae_entity = 'OPCL'
         AND dae_code = flt.ack_code;
         
        IF fdoc > 0 THEN
         FOR docs in c_docs(flt.ack_code) LOOP
            INSERT INTO R5DOCENTITIES
               (dae_document,dae_entity,dae_rentity,dae_type,
               dae_rtype,dae_code,dae_copytowo,dae_printonwo,
               dae_copytopo,dae_printonpo,dae_createcopytowo)
            SELECT
               dae_document,'EVNT','EVNT',dae_type,dae_rtype,
               ceventno,dae_copytowo,'+',dae_copytopo,
               dae_printonpo,dae_createcopytowo
            FROM R5DOCENTITIES
            WHERE dae_entity = 'OPCL'
               AND dae_code = flt.ack_code
               AND dae_document = docs.dae_document;
         END LOOP;
        END IF;
        
        vOckUDF02 := vOckUDF02 || ceventno ||'/';
      END LOOP;
      
      UPDATE R5OPERATORCHECKLISTS
      SET ock_udfchar02 = substr(vOckUDF02,1,80)
      WHERE ROWID = :rowid;
    END IF;
  END IF;

EXCEPTION
  WHEN err THEN
    RAISE_APPLICATION_ERROR (-20003, imsg);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR (-20003,
      'ERR/R5OPERATORCHECKLISTS/40/U'||Substr(SQLERRM, 1, 500));
END;