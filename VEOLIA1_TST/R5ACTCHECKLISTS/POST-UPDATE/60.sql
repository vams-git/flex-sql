declare 
  ack             r5actchecklists%rowtype; 
  obj             r5objects%rowtype;
  vOrg            r5organization.org_code%type;
  cOrg            number;
  vTask           r5activities.act_task%type;
  vTaskClass      r5tasks.tsk_class%type;
  cevtstat    r5events.evt_status%type;
  ceventno    r5events.evt_code%type;
  chk         varchar2(3);
  vWODesc     r5events.evt_desc%type;
  vFollowMRC  r5events.evt_mrc%type;
  vDateTime   date;
  vDate       date;
  vProject    r5events.evt_project%type;
  vProjBud    r5events.evt_projbud%type;
  vEvtLtype   r5events.evt_ltype%type;
  vCnt        number;
  

  iErrMsg         VARCHAR2(400);
  err_val         exception;
  
  cursor cur_origcomment(vEvt varchar2) is 
   select * from r5addetails
   where add_entity='EVNT' and add_code = vEvt
   order by add_line;
  
begin
  begin
    select * into ack from r5actchecklists where rowid=:rowid
    and ack_sequence = 50 and ack_yes = '+' 
    and ack_event is not null;
  exception when no_data_found then
    RETURN;
  end;
  

  select tch_task,t.tsk_class into vTask,vTaskClass
  from r5taskchecklists tch,r5tasks t
  where tch.tch_task = t.tsk_code and tch.tch_taskrev = t.tsk_revision
  and   tch_code = ack.ack_taskchecklistcode;
  vOrg := ack.ack_object_org;
  select count(1) into cOrg from r5organization,r5organizationoptions where org_code = vOrg and opa_org = vOrg and opa_code = 'CORRIMMI' and NVL(opa_desc,'NO') != 'NO';
  if cOrg != 0 then
  
      select NVL((REGEXP_SUBSTR(opa_desc, '\{{([^}]+)\}}',1,1,NULL,1)),'15TV') into cevtstat from r5organization,r5organizationoptions where org_code = vOrg and opa_org = vOrg and opa_code = 'CORRIMMI' and NVL(opa_desc,'NO') != 'NO';
  
      if vTaskClass = 'CORR' then
         if ack.ack_notes is null then
            iErrMsg := 'Note is mandatory for Checklist Sequence 50';
            raise err_val;
         end if;
     
     /*if nvl(ack.ack_followup,'-') ='-' then
        update r5actchecklists
            set ack_followup = '+'  
            where ack_code = ack.ack_code;  
     end if;*/
         
         vDateTime := o7gttime(vOrg);
         vDate := trunc(o7gttime(vOrg));
         
         select evt_project,evt_projbud,evt_ltype into vProject,vProjBud,vEvtLtype
         from r5events where evt_code = ack.ack_event;
       
         
         
         select * into obj from r5objects where obj_code = ack.ack_object and obj_org = ack.ack_object_org;
               
         vWODesc:= substr(ack.ack_notes,1,80); 
         vWODesc:= substr(obj.obj_udfchar16 || ' - ' ||ack.ack_notes,1,80);
         vFollowMRC := obj.obj_mrc;
     
     select count(1) into vCnt from r5events
     where evt_org = vOrg
     and   evt_object = obj.obj_code and evt_object_org = obj.obj_org
         and   evt_desc = vWODesc
         and   evt_status = cevtstat;
         
     if vCnt = 0 then
       r5o7.o7maxseq( ceventno, 'EVENT', '1', chk );
       insert into r5events
       (EVT_ORG,EVT_CODE,EVT_TYPE,EVT_RTYPE,EVT_MRC,EVT_LTYPE,EVT_LOCATION,EVT_LOCATION_ORG,EVT_COSTCODE,EVT_PROJECT,EVT_PROJBUD,EVT_OBTYPE,EVT_OBJECT,EVT_OBJECT_ORG,EVT_ISSTYPE, EVT_FIXED,
        EVT_DATE,EVT_TARGET,EVT_SCHEDEND,EVT_DURATION,EVT_REPORTED,EVT_ENTEREDBY,EVT_CREATED,EVT_CREATEDBY,
        EVT_ORIGWO,EVT_ORIGACT,EVT_DESC,EVT_JOBTYPE,EVT_CLASS,EVT_CLASS_ORG,EVT_STATUS,EVT_PRIORITY,
        evt_udfchar27,evt_udfchar29)
        VALUES
        (vOrg,ceventno,'JOB','JOB',vFollowMRC,vEvtLtype,obj.obj_location,obj.OBJ_LOCATION_ORG,obj.obj_costcode,vProject,vProjBud,obj.OBJ_OBTYPE,obj.OBJ_CODE,obj.OBJ_ORG,'F','V',
        vDateTime,vDate,vDate,1,vDateTime,o7sess.cur_user,vDateTime,o7sess.cur_user,
        ack.ack_event,ack.ack_act,vWODesc,'RQ','CO','*',cevtstat,null,
        ack.ack_event,vFollowMRC
        ); 
        o7creob1( ceventno, 'JOB', obj.obj_code, obj.obj_org, obj.obj_obtype, obj.obj_obrtype, chk );
		o7descs( 'UPD', null, 'EVNT', null, '*', ceventno, vOrg,vWODesc, chk);
                
        
        /*update r5actchecklists
        set ack_followupevent = ceventno--,ack_followupact = 10
        where ack_code = ack.ack_code
        and nvl(ack_followupevent,' ') <> ceventno;*/
         
             
         /*for rec_wocomm in cur_origcomment(ack.ack_event) loop
          insert into r5addetails
          (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,
          add_created,add_user)
          values
          (rec_wocomm.add_entity,rec_wocomm.add_rentity,rec_wocomm.add_type,rec_wocomm.add_rtype,ceventno,rec_wocomm.add_lang,rec_wocomm.add_line,rec_wocomm.add_print,rec_wocomm.add_text,
          vDateTime,o7sess.cur_user);  
        end loop;*/
     end if; --vCnt = 0
     
      end if; --vTaskClass = 'CORR'
    end if; --vOrg in 
EXCEPTION
   when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   /*when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5ACTCHECKLISTS/Post Update/60/'||substr(SQLERRM, 1, 500)) ; */
end;
