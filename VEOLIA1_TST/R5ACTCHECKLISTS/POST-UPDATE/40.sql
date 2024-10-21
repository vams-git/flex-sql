declare 
  ack             r5actchecklists%rowtype; 
  evt             r5events%rowtype;
  vOrg            r5organization.org_code%type;
  vStatus         r5events.evt_status%type;
  vTask           r5activities.act_task%type;
  vTaskClass      r5tasks.tsk_class%type;
  vTaskRev        r5tasks.tsk_revision%type;
  vMailTemp       r5mailevents.mae_code%type;
  iErrMsg         VARCHAR2(400);
  err_val         exception;
  
begin
  select * into ack from r5actchecklists where rowid=:rowid;
  if ack.ack_event is null then
    return;
  end if;

  begin
    /*select evt_org,act_task,act_taskrev
    into vOrg,vTask,vTaskRev
    from r5activities,r5events 
    where evt_code = act_event
    and   act_event = ack.ack_event and act_act = ack.ack_act;
    
    if vTask is not null then
       select tsk_class into vTaskClass from r5tasks where tsk_code = vTask and tsk_revision = vTaskRev;
    end if;
    --mutating error, could not get information from r5activies directly
    */
    select tch_task,t.tsk_class into vTask,vTaskClass
    from r5taskchecklists tch,r5tasks t
    where tch.tch_task = t.tsk_code and tch.tch_taskrev = t.tsk_revision
    and   tch_code = ack.ack_taskchecklistcode;
    vOrg := ack.ack_object_org;
  exception when no_data_found then 
     vTaskClass := null;
  end;

  if vTaskClass = 'CORR' then
  --if vTask = 'HWC-CHK-T-0100' then
    if (ack.ack_sequence = 50) or (ack.ack_sequence = 51 and vStatus IN('50SO','51SO') ) then
   --if ack.ack_sequence in (50,51) then
     if ack.ack_yes = '+' and ack.Ack_Notes is null then
        iErrMsg := 'Note is mandatory for Checklist Sequence ' || ack.ack_sequence;
        raise err_val;
     end if;
     if ack.ack_yes = '+' then
       update r5actchecklists
       set    ack_followup ='+'
       where  ack_code = ack.ack_code
       and    ack_followup not in ('+');
      else
        update r5actchecklists
       set    ack_followup ='-'
       where  ack_code = ack.ack_code
       and    ack_followup not in ('-');
      end if;
     end if;
     
     if ack.ack_sequence = 51 and ack.ack_yes = '+' and vStatus IN('50SO','51SO') then
        select * into evt from r5events where evt_code = ack.ack_event;
        vMailTemp := 'M-'||evt.evt_org ||'-PMERROR';
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
        (S5MAILEVENT.NEXTVAL,
        --'M-HWC-PMERROR',
         vMailTemp,
         SYSDATE,'-','N',
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
 
EXCEPTION
   when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5ACTCHECKLISTS/Post Update/40/'||substr(SQLERRM, 1, 500)) ; 
end;
