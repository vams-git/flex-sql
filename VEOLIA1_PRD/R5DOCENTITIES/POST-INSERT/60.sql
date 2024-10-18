declare 
  dae        r5docentities%rowtype;
  
  ack        r5actchecklists%rowtype;
  vOrg       r5operatorchecklists.ock_org%type;
  vEvts      r5operatorchecklists.ock_udfchar02%type;
  vTask      r5tasks.tsk_code%type;
  vOckStatus r5operatorchecklists.ock_status%type;
  
  vFaultNote r5actchecklists.ack_notes%type;
  vDocClass  r5documents.doc_class%type;
  vDocDesc   r5documents.doc_desc%type;
  vCnt       number;
  
  cursor cur_evt(vOpCode varchar2,vOrg varchar2) is 
  select distinct ack_code,ack_event,ack_notes,ack_finding
  from   r5actchecklists
  where  ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and    ack_event is not null;
begin
   select * into dae from r5docentities where rowid=:rowid;
   if dae.dae_entity in ('OPCL') then 
       begin
         --get task checklist 
         select * into ack from r5actchecklists where ack_Code = dae.dae_code;
         --get opc task
         select ock_org,ock_task,ock_udfchar02,ock_status into vOrg,vTask,vEvts,vOckStatus from r5operatorchecklists
         where  ock_code = ack.ack_entitykey  and ock_org = ack.ack_entityorg;
         
         if vTask = 'CAUS-CHK-T-0002' and vOckStatus = 'C' then
            --update document desc 
            if ack.ack_sequence = 400 then
               select doc_class into vDocClass from r5documents where doc_code = dae.dae_document;
               if nvl(vDocClass,' ') <> 'VEHI' then
                   -- select substr('DVR_'||vFaultNote||'_'||to_char(o7gttime(ock.ock_org),'DDMONYYYY_HH24_MI'),1,80)
                   select substr('DVR_'||ack.ack_notes||'_'||to_char(o7gttime(vOrg),'DDMONYYYY_HH24_MI'),1,80)
                   into   vDocDesc from dual;
                   update r5documents d
                   set d.doc_desc = vDocDesc,
                   doc_class = 'VEHI',d.doc_class_org = '*'
                   where d.doc_code = dae.dae_document;
               end if; --vDocClass <> 'VEHI'
            end if; --ack.ack_sequence = 400
            --update document desc 
            if ack.ack_sequence = 405 then 
               --substr(r5o7.o7get_desc('EN','FIND',rec_doc.ack_finding,'','') ||'_DVR_'||vFaultNote||'_'||to_char(o7gttime(ock.ock_org),'DDMONYYYY_HH24_MI'),1,80)
               select doc_class into vDocClass from r5documents where doc_code = dae.dae_document;
               if nvl(vDocClass,' ') <> 'VEHI' then
                   begin
                     select ack_notes into vFaultNote 
                     from r5actchecklists ack400
                     where ack400.ack_entitykey = ack.ack_entitykey and ack400.ack_entityorg = ack.ack_entityorg
                     and   ack400.ack_sequence = 400;
                   exception when no_data_found then
                     vFaultNote := null;
                   end;
                   
                   select substr(r5o7.o7get_desc('EN','FIND',ack.ack_finding,'','') ||'_DVR_'||vFaultNote||'_'||to_char(o7gttime(vOrg),'DDMONYYYY_HH24_MI'),1,80)
                   into   vDocDesc from dual;
                   update r5documents d
                   set   doc_desc = vDocDesc,doc_class = 'VEHI',d.doc_class_org = '*'
                   where doc_code = dae.dae_document;
               end if; --vDocClass <> 'VEHI'
            end if; --ck.ack_sequence = 405
            if ack.ack_sequence = 500 then
               select doc_class into vDocClass from r5documents where doc_code = dae.dae_document;
               if nvl(vDocClass,' ') <> 'VEHI' then
                  update r5documents d
                  set    doc_class = 'VEHI',d.doc_class_org = '*'
                  where  doc_code = dae.dae_document;
               end if;
            end if;
              
            
             --link document with WO if it does not exist
             if vEvts is not null then 
               --just copy to corresponding evt document
               if ack.ack_sequence = 405 then 
                   select count(1) into vCnt from r5docentities
                    where dae_entity = 'EVNT' and dae_code = ack.ack_event and dae_document = dae.dae_document;
                    if vCnt = 0 then
                       insert into r5docentities
                       (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
                       values
                       (dae.dae_document,'EVNT','EVNT',dae.dae_type,dae.dae_rtype,ack.ack_event,'-','+','-','-','-');
                    end if;
                end if;
                --for 400, 500, copy document to all related work order
                if ack.ack_sequence <> 405 then 
                    for rec_evt in cur_evt(ack.ack_entitykey,ack.ack_entityorg) loop
                       select count(1) into vCnt from r5docentities
                       where dae_entity = 'EVNT' and dae_code = rec_evt.ack_event and dae_document = dae.dae_document;
                       if vCnt = 0 then
                          insert into r5docentities
                          (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
                          values
                          (dae.dae_document,'EVNT','EVNT',dae.dae_type,dae.dae_rtype,rec_evt.ack_event,'-','+','-','-','-');
                       end if;
                    end loop;
                end if; --ack.ack_sequence <> 405 
               
             end if; --if vEvts is not null then 
             
         end if; --if vTask = 'CAUS-CHK-T-0002' then
                
       exception when no_data_found then
         null;
       end;
   end if; -- dae.dae_entity in ('OPCL')

exception 
  when others then
     RAISE_APPLICATION_ERROR (  -20003,'Error in Flex r5docentities/Post Insert/60/'||substr(SQLERRM, 1, 500)) ; 
end;