DECLARE
    cCode           R5EVENTS.EVT_CODE%TYPE;
    cppm            R5EVENTS.Evt_Ppm%TYPE;
    cppmRev         R5EVENTS.Evt_Ppmrev%TYPE;
    cCreatedBy      R5EVENTS.Evt_CreatedBy%TYPE;
    cact            R5ACTIVITIES.Act_Act%TYPE;
    cTrade          R5ACTIVITIES.act_trade%TYPE;
    cEst            R5ACTIVITIES.act_est%TYPE;
    cPersons        R5ACTIVITIES.act_persons%TYPE;
    cDuration       R5ACTIVITIES.act_duration%TYPE;
    cCommCode       R5COMMENTS.add_code%TYPE;     
    cEvtCommCode    R5COMMENTS.add_code%TYPE; 
    cAddLang        R5COMMENTS.ADD_LANG%TYPE; 
    cAddLine        R5COMMENTS.ADD_LINE%TYPE; 
    cAddPrint       R5COMMENTS.ADD_PRINT%TYPE; 
    cAddText        R5COMMENTS.ADD_TEXT%TYPE; 
    cPPMCnt         NUMBER;
    cActCommCnt     Number;
    
    rec_add         r5addetails%rowtype;
    
    iText varchar2(32767); 
    cursor getcomments IS
    select * 
    FROM r5addetails 
    WHERE ADD_ENTITY = 'PPM' AND ADD_RENTITY = 'PPM'
    AND ADD_CODE =  cCommCode and rownum = 1 ;
    
BEGIN  
     SELECT act_event,act_act,act_trade,act_est,act_persons,act_duration
     INTO cCode, cact,cTrade,cEst,cPersons,cDuration
     FROM R5ACTIVITIES
     WHERE ROWID=:ROWID;
      
     SELECT evt_ppm,evt_ppmrev,Evt_CreatedBy
     INTO   cppm,cppmRev,cCreatedBy
     FROM   R5EVENTS 
     WHERE  evt_code = cCode;
     
     IF cppm is not null THEN
        --Is PPM Activity?
        cPPMCnt := 0;
        SELECT COUNT(1) INTO cPPMCnt
        FROM R5PPMACTS 
        WHERE PPA_PPM = cppm AND PPA_ACT = cact
        AND   PPA_TRADE = cTrade
        AND   PPA_EST = cEst
        AND   PPA_PERSONS = cPersons
        AND   PPA_DURATION = cDuration;
        
        --Has Comments?
        cCommCode := cppm || '#' || cppmRev || '#' || cact;
        cActCommCnt := 0;
        SELECT COUNT(1) into cActCommCnt
        FROM R5COMMENTS
        WHERE ADD_ENTITY = 'PPM' AND ADD_RENTITY = 'PPM'
        AND ADD_CODE =  cCommCode;
        
        IF cPPMCnt > 0 AND cActCommCnt > 0 THEN
           cEvtCommCode := cCode || '#' || cact;
           
           select * into rec_add
           FROM r5addetails
           WHERE ADD_ENTITY = 'PPM' AND ADD_RENTITY = 'PPM'
           AND ADD_CODE =  cCommCode and rownum = 1;
           
           -- iText := substr ( o7trimtags(cAddText), 1, 4000); 
           iText :=  dbms_lob.substr(R5REP.TRIMHTML(rec_add.add_code,rec_add.add_entity,rec_add.add_type,'EN',rec_add.add_line),3500,1);
           INSERT INTO r5addetails
           (ADD_ENTITY,ADD_RENTITY,ADD_TYPE,ADD_RTYPE,ADD_CODE,ADD_LANG,ADD_LINE,ADD_PRINT,ADD_TEXT,
           ADD_CREATED,ADD_USER,ADD_UPDATED,ADD_UPDUSER,ADD_UPDATECOUNT)
           VALUES
           ('EVNT','EVNT','*','*',cEvtCommCode,rec_add.add_lang,rec_add.add_line,rec_add.add_print ,iText ,
           SYSDATE,cCreatedBy,NULL,NULL,0);  
           
          
           /*SELECT 'EVNT','EVNT','*','*',cEvtCommCode,ADD_LANG,ADD_LINE,ADD_PRINT,ADD_TEXT,SYSDATE,cCreatedBy,
           NULL,NULL,0
           FROM R5COMMENTS
           WHERE ADD_ENTITY = 'PPM' AND ADD_RENTITY = 'PPM'
           AND ADD_CODE =  cCommCode;*/
        END IF;
     END IF;
END;
