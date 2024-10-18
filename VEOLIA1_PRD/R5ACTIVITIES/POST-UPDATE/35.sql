declare 
    act r5activities%rowtype;
    vCnt  number;
    
    CURSOR c_TaskDocs(vDaeCode varchar2) IS
    SELECT dae_document,dae_entity,dae_code,doc_udfchkbox01,doc_udfchkbox02
    FROM   r5documents, r5docentities
    WHERE  doc_code = dae_document
    AND    dae_rentity = 'TASK'
    AND    dae_code = vDaeCode
    AND    doc_udfchkbox01 = '+'
    AND    doc_notused = '-';
 

begin
    select * into act from r5activities where rowid=:rowid;
    if act.act_task is not null then
       for rec_taskdoc in c_TaskDocs(act.act_task||'#'||act.act_taskrev) loop
           select count(1) into vCnt from r5docentities
           where dae_document = rec_taskdoc.dae_document
           and   dae_entity ='EVNT'
           and   dae_code = act.act_event;
           if vCnt = 0 then
               INSERT INTO r5docentities
               (dae_document,dae_entity, dae_rentity,
                dae_type,dae_rtype,dae_code,dae_printonpo, dae_printonwo)
               values
               (rec_taskdoc.dae_document,'EVNT','EVNT','*','*',act.act_event,'-',rec_taskdoc.doc_udfchkbox02);
           end if;
       end loop;
    end if;
    
    
exception 
  when others then
  RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex r5activities/Post Insert/35/'||substr(SQLERRM, 1, 500)) ;     
end;
