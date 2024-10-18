declare 
  ack             r5actchecklists%rowtype; 
  evt             r5events%rowtype;
  vOrg            r5organization.org_code%type;
  vStatus         r5events.evt_status%type;
  vTask           r5activities.act_task%type;
  vCount          number;
  iErrMsg         VARCHAR2(400);
  err_val         exception;
  
begin
  select * into ack from r5actchecklists where rowid=:rowid;
  if ack.ack_event is null then
    return;
  end if;
  
 begin
   select evt_org into vOrg from r5events
   where evt_code = ack.ack_event;
  /*select evt_org,act_task into vOrg,vTask 
  from r5activities,r5events 
  where evt_code = act_event
  and   act_event = ack.ack_event and act_act = ack.ack_act;*/
  
  --select tch_task into vTask from r5taskchecklists where tch_code = ack.ack_taskchecklistcode;
  --vOrg := ack.ack_object_org;
  exception when no_data_found then
    vOrg := null;
    vTask:= null;
  end;
  
  if vOrg in ('QTN') and ack.ack_sequence = 205000 and vStatus = '49MF' then
     if ack.ack_yes = '+' and ack.Ack_Notes is null then
        iErrMsg := 'Note is mandatory for Checklist Sequence ' || ack.ack_sequence;
        raise err_val;
     end if;
     if ack.ack_yes = '+' then
        select * into evt from r5events where evt_code = ack.ack_event;
        select count(1) into vCount
        from r5mailevents
        where MAE_TEMPLATE = 'M-'||evt.evt_org||'-PMERROR'
        and   MAE_PARAM2 = evt.evt_code;
        if vCount = 0 then
          insert into r5mailevents
          (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
           MAE_PARAM1,--org
           MAE_PARAM2,--wo
           MAE_PARAM3,--wo desc
           MAE_PARAM4,--element
           MAE_PARAM6,--WO Class
           MAE_PARAM7,--Status
           MAE_PARAM8,--Site
           MAE_PARAM9,--Unit
           MAE_PARAM10,--Tag Code
           MAE_PARAM11,--Poistion
           MAE_PARAM13,--Priority
           MAE_PARAM15,MAE_ATTRIBPK) 
          values
          (S5MAILEVENT.NEXTVAL,'M-'||vOrg||'-PMERROR',SYSDATE,'-','N',
           evt.evt_org,
           evt.evt_code,
           evt.evt_desc,
           evt.evt_object,
           evt.evt_class,
           r5o7.o7get_desc('EN','UCOD',evt.evt_status,'EVST', ''),
           evt.evt_udfchar04,
           evt.evt_udfchar08,
           (select obj_udfchar15 from r5objects where obj_code = evt.evt_object and obj_org = evt.evt_object_org),
           evt.evt_udfchar12,
           r5o7.o7get_desc('EN','UCOD',evt.evt_jobtype,'JBPR',''),
           o7sess.cur_user,
           0);
       end if;
     end if;
  end if; 
    

EXCEPTION
   when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5ACTCHECKLISTS/Post Update/45/'||substr(SQLERRM, 1, 500)) ; 

end;
