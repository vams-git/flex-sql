declare 
   ock              r5operatorchecklists%rowtype;
   obj              r5objects%rowtype;
   vTskClass        r5classes.cls_code%type;
   vHasFault        r5actchecklists.ack_yes%type;
   vHasNoFault      r5actchecklists.ack_no%type;
   vFaultNote       r5actchecklists.ack_notes%type;
   vFaultCnt        number;
   vFaultCategoryExist number;
   vFaultCategoryCnt number;
   vIsReported      number;
   vFaultNoteCnt    number;
   ceventno         r5events.evt_code%type;
   vAct		        r5activities.act_act%type;
   vDateTime        date;
   vDate            date;
   vWODesc          r5events.evt_desc%type;
   vUDFChar27       r5events.evt_udfchar27%type;
   chk              varchar2(3);
   vCommLine        r5addetails.add_line%type;
   vComm            varchar2(4000);
   vComm400         varchar2(4000);
   vDocDesc         r5documents.doc_desc%type;
   vAssignto        r5personnel.per_code%type;
   vFirst405Notes   r5actchecklists.ack_notes%type;
   vNotes500        r5actchecklists.ack_notes%type;
   vEvtMrc          r5mrcs.mrc_code%type;
   vFndMrc          r5mrcs.mrc_code%type;
   
   vObjLastDVRDate  date;
   vPosLastDVRDate  date;
   vObtype          r5objects.obj_obtype%type;
   vPosition        r5objects.obj_position%type;
   vPositionOrg     r5objects.obj_position_org%type;
   vVehicle         r5objects.obj_vehicle%type;
   
   vOckUDF02       r5operatorchecklists.ock_udfchar02%type;
   
   vSTDWO          r5events.Evt_Standwork%type;
   v_Fnd_440       r5actchecklists.ack_finding%type;
   iErrMsg         varchar2(200);
   err             exception;
   
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
   
  cursor cur_opdoc(vOpCode varchar2,vOrg varchar2) is 
  select ack.ack_code,dae.dae_document,doc.doc_code,
  ack.ack_sequence,ack.ack_finding,ack.ack_notes
  from  r5actchecklists ack,r5docentities dae,r5documents doc
  where ack_code = dae_code
  and   dae_document = doc_code
  and   dae_entity = 'OPCL'  
  and   ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and   ack_sequence not in (405);
  
  cursor cur_opdoc_405(vOpCode varchar2,vOrg varchar2,vAckCode varchar2) is 
  select ack.ack_code,dae.dae_document,doc.doc_code,
  ack.ack_sequence,ack.ack_finding,ack.ack_notes
  from  r5actchecklists ack,r5docentities dae,r5documents doc
  where ack_code = dae_code
  and   dae_document = doc_code
  and   dae_entity = 'OPCL'  
  and   ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and   ack_code = vAckCode
  and   ack_sequence in (405);
  
  --and   ack_sequence in (131,135,250);
  cursor cur_fault(vOpCode varchar2,vOrg varchar2) is 
  select ack.ack_code,ack_finding,ack_notes,fnd_desc
  from r5actchecklists ack,r5findings
  where ack_finding = fnd_code
  and   ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and   ack_sequence in (405)
  and   ack_finding is not null
  order by ack_code;
  
  cursor cur_mrc(vOpCode varchar2,vOrg varchar2) is 
  select ack_finding,ack_notes,fnd_desc
  from r5actchecklists,r5findings
  where ack_finding = fnd_code
  and   ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and   ack_sequence in (450)
  and   ack_finding is not null;
  
  CURSOR act( wo VARCHAR2 ) IS
  SELECT act_act, act_warranty, act_syslevel, act_asmlevel, act_complevel, act_rpc, act_wap, act_task, act_taskrev
  FROM   r5activities
  WHERE  act_event = wo;
  
begin
   select * into ock from r5operatorchecklists where rowid=:rowid;-- ock_code = '27562';
   if ock.ock_rstatus in ('U','CC') then
      return;
   end if;

   select tsk_class into vTskClass
   from r5tasks where tsk_code = ock.ock_task and tsk_revision = ock.ock_taskrev;
   if vTskClass ='VCON' then
      if ock.ock_udfchar02 is not null then
         return;
      end if;  
      
      --update asset obj_udfdate04
      select obj_udfdate04,obj_obtype,obj_position,obj_position_org,obj_vehicle
      into   vObjLastDVRDate,vObtype,vPosition,vPositionOrg,vVehicle from r5objects 
      where obj_code = ock.ock_object and obj_org = ock.ock_object_org;      
      if vObjLastDVRDate is null or vObjLastDVRDate < ock.ock_enddate then
         update r5objects 
         set    obj_udfdate04 = ock.ock_enddate
         where  obj_code = ock.ock_object and obj_org = ock.ock_object_org;      
      end if;
      
      if vVehicle ='+' then
         for rec_parent in cur_parent(ock.ock_object,ock.ock_object_org) loop 
            if rec_parent.obj_udfdate04 is null or rec_parent.obj_udfdate04 < ock.ock_enddate then
                update r5objects 
                set    obj_udfdate04 = ock.ock_enddate
                where  obj_code = rec_parent.obj_code and obj_org = rec_parent.obj_org;
            end if;
         end loop;
      end if;
      /*
      if vObtype ='06EQ' and vVehicle ='+' and vPosition is not null then
         select obj_udfdate04 into vPosLastDVRDate
         from r5objects where obj_code = vPosition and obj_org = vPositionOrg;
         if vPosLastDVRDate is null or vPosLastDVRDate < ock.ock_enddate then
            update r5objects 
            set    obj_udfdate04 = ock.ock_enddate
            where  obj_code = vPosition and obj_org = vPositionOrg;
         end if;
      end if;*/
       --end update asset obj_udfdate04
   
      begin
        select ack_yes,ack_notes,ack_no
          into vHasFault,vFaultNote,vHasNoFault
        from r5actchecklists
        where ack_rentity = 'OPCK'
          and ack_entitykey = ock.ock_code
          and ack_entityorg = ock.ock_org
          and ack_sequence in (400);
      exception when no_data_found then 
        vHasFault := '-'; 
        vHasNoFault := '-';
      end;
      
      if vFaultNote is null then
          --iErrMsg := 'Please Fill in note for item #400.';
          iErrMsg := 'DVR number is missing in note field of first question.';
          raise err;
      end if;
      
      select count(1) into vFaultCnt
      from r5actchecklists
      where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
      and   ack_sequence in (405)
      and   ack_finding is not null;
      
      --Yes/No is a must for questions 400, 
      if vHasFault = '-' and vHasNoFault = '-' then 
         iErrMsg := 'Please select Yes/No  for the first question.';
         raise err;
      end if;
      
      --Any fault is filline, user could not answer No/None for questions 400, 
      if vHasFault = '-' and vFaultCnt > 0 then 
         iErrMsg := 'You are trying to record the detail of a faulty system, please amend answer to first question.';
         raise err;
      end if;
      
      --Update document desc for attached picutre for item 400
      for rec_doc in cur_opdoc(ock.ock_code,ock.ock_org) loop
          if rec_doc.ack_sequence in (400) then
              select substr('DVR_'||vFaultNote||'_'||to_char(o7gttime(ock.ock_org),'DDMONYYYY_HH24_MI'),1,80)
              into   vDocDesc from dual;
              update r5documents d
              set d.doc_desc = vDocDesc,
              doc_class = 'VEHI',d.doc_class_org = '*'
              where d.doc_code = rec_doc.doc_code;
          end if;
      end loop;
      
      if vHasFault = '+' then 
         if vFaultCnt < 1 then
            iErrMsg := 'Please indicate at least one system and fault identified.';
            raise err;
         end if;

		 select count(1) into vFaultCategoryExist
		 from r5actchecklists
         where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
         and   ack_sequence in (440);
		 
		 select count(1) into vFaultCategoryCnt
		 from r5actchecklists
         where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
         and   ack_sequence in (440)
         and   ack_finding is not null;
         
		 if vFaultCategoryExist != 0 AND vFaultCategoryCnt < 1 then
            iErrMsg := 'Please indicate at least one category of the faults reported.';
            raise err;
         end if;
         
         select count(1) into vFaultNoteCnt
         from r5actchecklists
         where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
         and   ack_sequence in (405)
         and   ack_finding is not null and ack_notes is null;
         if vFaultNoteCnt > 0 then
            iErrMsg := 'Please fill in note for identified system and fault.';
            raise err;
         end if;
         
         if vHasFault = '+' then 
           begin
               select count(1),ack_notes
               into vIsReported,vNotes500
               from r5actchecklists
               where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
               and   ack_sequence in (500)
               and   (nvl(ack_yes,'-')||nvl(ack_no,'-')) <> '--'
               group by ack_notes;
               if vIsReported < 1 then
                  iErrMsg := 'Please indicate have you reported all faults and notified the supervisor or authorised person.';
                  raise err;
               end if;
           exception WHEN no_data_found then
              iErrMsg := 'Please indicate have you reported all faults and notified the supervisor or authorised person.';
              raise err;
           end;
         end if;
         
         begin
           select ack_finding into v_Fnd_440
           from r5actchecklists
           where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
           and   ack_sequence in (440) 
           and   ack_finding is not null;
           
           select std.stw_code into vSTDWO
           from r5standworks std
           where std.stw_org = ock.ock_org and std.stw_class = replace(v_Fnd_440,'F','FL-')
           and rownum <= 1;
           
        exception when no_data_found then
           vSTDWO := null;
        end;
        
        if v_Fnd_440 is not null and vSTDWO is null then
           iErrMsg := 'Standard Work order is not found for category of fault(s).';
           raise err;
        end if;
         
       
        begin
             select p.per_code into vAssignto
             from r5personnel p where p.per_user = ock.ock_createdby;
         exception when no_data_found then
             vAssignto := null;
         end;
         
         for rec_fault in cur_fault(ock.ock_code,ock.ock_org) loop      
             --create work order 
             r5o7.o7maxseq( ceventno, 'EVENT', '1', chk );
             select * into obj from r5objects where obj_code = ock.ock_object and obj_org = ock.ock_object_org;
             vDateTime := o7gttime(ock.ock_org);
             vDate := trunc(o7gttime(ock.ock_org));
         
             begin
               --select ack_notes into vFirst405Notes from (
               select ack_notes  into vFirst405Notes
               from r5actchecklists
               where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
               and   ack_sequence in (405)
               and   ack_finding is not null and ack_notes is not null
               and   ack_code = rec_fault.ack_code;
               --order by ack_code)
               --where rownum<=1;
             exception when no_data_found then
                  vFirst405Notes := null;
             end;
             
         
             vEvtMrc := obj.obj_mrc;
             for rec_mrc in cur_mrc(ock.ock_code,ock.ock_org) loop
               begin
                   select 
                   nvl(substr(rec_mrc.fnd_desc, 0, instr(rec_mrc.fnd_desc, ' ')-1), rec_mrc.fnd_desc) into vFndMrc
                   from dual;

                   select mrc_code into vEvtMrc
                   from r5mrcs 
                   where mrc_code = trim(vFndMrc);
               exception 
                 when no_data_found then
                   null;
               end;
             end loop;

  
             --vWODesc := substr('DVR#' || vFaultNote || ' - ' || obj.obj_desc,1,80);
             vWODesc := substr('DVR - ' || obj.obj_udfchar16 || ' - ' || vFirst405Notes,1,80);
             vUDFChar27 := substr('DVR#' || vFaultNote,1,80);
             
             insert into r5events e
             (EVT_ORG,EVT_CODE,EVT_TYPE,EVT_RTYPE,EVT_MRC,EVT_LTYPE,EVT_LOCATION,EVT_LOCATION_ORG,EVT_COSTCODE,EVT_PROJECT,EVT_PROJBUD,EVT_OBTYPE,EVT_OBJECT,EVT_OBJECT_ORG,EVT_ISSTYPE,EVT_FIXED,
              EVT_DATE,EVT_TARGET,EVT_SCHEDEND,EVT_DURATION,EVT_REPORTED,EVT_ENTEREDBY,EVT_CREATED,EVT_CREATEDBY,
              EVT_ORIGWO,EVT_ORIGACT,EVT_DESC,EVT_JOBTYPE,EVT_CLASS,EVT_CLASS_ORG,EVT_STATUS,EVT_PRIORITY,EVT_PERSON,EVT_ORIGIN,
              evt_udfchar27,evt_udfchar29,evt_standwork)
              VALUES
              (ock.ock_org,ceventno,'JOB','JOB',vEvtMrc,obj.obj_ltype,obj.obj_location,obj.obj_location_org,obj.obj_costcode,null,null,obj.obj_obtype,obj.obj_code,obj.obj_org,'F','V',
              vDateTime,vDate,vDate,1,vDateTime,o7sess.cur_user,vDateTime,o7sess.cur_user,
              null,null,vWODesc,'RQ','CO','*','15TV',null,null,vAssignto,
              vUDFChar27,vEvtMrc,vSTDWO
              ); 
			  vAct := null;
              o7creob1( ceventno, 'JOB', obj.obj_code, obj.obj_org, obj.obj_obtype, obj.obj_obrtype, chk );
              if vSTDWO is not null then
                 o7cract1(ceventno,NULL,vSTDWO,NULL ,NULL,8,vDate, 'Q', NULL, NULL, NULL, NULL, vEvtMrc, chk );
                 
                 FOR i IN act( ceventno ) LOOP
				   if vAct is null then
					  vAct := i.act_act;
				   end if;
                  
                   IF i.act_task IS NOT NULL THEN
                      --iErrMsg := i.act_task;
                      --raise err;
                     o7createactchecklist(
                      ceventno,--event      IN  VARCHAR2,
                      i.act_act,--act        IN  NUMBER,
                      i.act_task,--'CAUS-T-0001',--task       IN  VARCHAR2,
                      i.act_taskrev,--0,--taskrev    IN  NUMBER,
                      null,--lotopk     IN  VARCHAR2,
                      '%',--childwo    IN  VARCHAR2 DEFAULT '%',
                      '-',--routeupd   IN  VARCHAR2 DEFAULT '-',
                      '-',--pointupd   IN  VARCHAR2 DEFAULT '-',
                      null,--objupd     IN  VARCHAR2 DEFAULT '-',
                      null,--operatorcl IN  VARCHAR2 DEFAULT NULL,
                      null,--casetask   IN  VARCHAR2 DEFAULT NULL,
                      null--nonconf    IN  VARCHAR2 DEFAULT NULL 
                      );
                   END IF;
                 END LOOP;
              end if;
			  
			  update r5actchecklists
			  set    ack_event = ceventno,ack_act = vAct
			  where  ack_code =  rec_fault.ack_code;
              
              vCommLine := 0;
              vComm := null;
                
              if vNotes500 is not null then
                vComm400 := 'Maintenance/SHEQ note:  ' || vNotes500;
                vCommLine := vCommLine + 10;
                insert into r5addetails
                (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,
                add_created,add_user)
                values
                ('EVNT','EVNT','*','*',ceventno,'EN',vCommLine,'+',vComm400,
                vDateTime,o7sess.cur_user);  
              end if;
              
              --for rec_fault in cur_fault(ock.ock_code,ock.ock_org) loop              
               vComm := vComm || 'Fault ' || rec_fault.fnd_desc || '. Note: ' || rec_fault.ack_notes || chr(10);
              --end loop;
              
              if vComm is not null then
                  vCommLine := vCommLine + 10;
                  insert into r5addetails
                  (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,
                  add_created,add_user)
                  values
                  ('EVNT','EVNT','*','*',ceventno,'EN',vCommLine,'+',vComm,
                  vDateTime,o7sess.cur_user);  
              end if;
              
              --Non 405 document (400,500)
              for rec_doc in cur_opdoc(ock.ock_code,ock.ock_org) loop
                 update r5documents d
                 set doc_class = 'VEHI',d.doc_class_org = '*'
                 where doc_code = rec_doc.doc_code
                 and   nvl(doc_class,' ' ) <> 'VEHI';
                  
                 insert into r5docentities
                 (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
                  select 
                  dae_document,'EVNT','EVNT',dae_type,dae_rtype,ceventno,dae_copytowo,'+',dae_copytopo,dae_printonpo,dae_createcopytowo
                  from r5docentities 
                  where dae_entity = 'OPCL'
                  and   dae_code = rec_doc.ack_code
                  and   dae_document = rec_doc.doc_code;
               end loop;
               
              --405 document
              for rec_doc in cur_opdoc_405(ock.ock_code,ock.ock_org,rec_fault.ack_code) loop
				  --Finding description+""_DVR""+ Note from sequence 500 + Date/timestamp in formatDDMMMYYY+""_""+HH+""_""+MM (With HH the hours and MM the minutes)
				  select substr(r5o7.o7get_desc('EN','FIND',rec_doc.ack_finding,'','') ||'_DVR_'||vFaultNote||'_'||to_char(o7gttime(ock.ock_org),'DDMONYYYY_HH24_MI'),1,80)
				  into   vDocDesc from dual;
					 
                  update r5documents d
                  set   doc_desc = vDocDesc,doc_class = 'VEHI',d.doc_class_org = '*'
                  where doc_code = rec_doc.doc_code;
                  
                  insert into r5docentities
                  (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
                   select 
                   dae_document,'EVNT','EVNT',dae_type,dae_rtype,ceventno,dae_copytowo,'+',dae_copytopo,dae_printonpo,dae_createcopytowo
                   from r5docentities 
                   where dae_entity = 'OPCL'
                   and   dae_code = rec_doc.ack_code
                   and   dae_document = rec_doc.doc_code;
				  
               end loop;
			   
              vOckUDF02 := vOckUDF02 || ceventno ||'/';
            end loop; -- loop cur_fault
          
          update r5operatorchecklists o
          set ock_udfchar02 = substr(vOckUDF02,1,80)
          where rowid =:rowid;
         
      end if; --vHasFault = '+'
          

   end if;--vTskClass ='VCON'

exception 
  when err then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
    RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5operatorchecklists/Post Update/20/'||substr(SQLERRM, 1, 500)) ;   
end;
