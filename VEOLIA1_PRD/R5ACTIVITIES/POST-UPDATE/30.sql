DECLARE 
  act          r5activities%rowtype;
  vOrg         r5organization.org_code%type;
  vFirstAct    r5activities.act_act%type;
  vFirstTask   varchar2(4);
  vTaskPrefix  varchar2(4);
  
  vCount       number;
  err_task_1   exception;
  err_task_2   exception;
  iErrMsg      varchar2(400); 
  iLang        r5users.usr_lang%type; 
BEGIN 
  select * into act from r5activities where rowid=:rowid;
  select evt_org
  into vOrg
  from r5events
  where evt_code=act.act_event;
  
  if vOrg in ('WBP') and act.act_task is not null then
    --get first activity with task plan
    vTaskPrefix := substr(act.act_task,5,2);
    begin
     select act_act,substr(act_task,5,2) into vFirstAct,vFirstTask
     from (
     select act_act,act_task
     from r5activities
     where  act_event = act.act_event
     and    act_task is not null
     order by act_act
     ) where rownum <= 1;
     
     if instr(vFirstTask,'-AD') > 0 then 
       raise err_task_2;
     end if;
     select count(1) into vCount
     from  r5activities a1
     where a1.act_event = act.act_event
     and   a1.act_task is not null
     and   substr(a1.act_task,5,2) <> vFirstTask;
     if vCount > 0 then
       raise err_task_1;
     end if;
     select count(1) into vCount
     from  r5activities a1
     where a1.act_event = act.act_event
     and   a1.act_task is not null
     and   instr(a1.act_task,'-AD') <= 0;
     if vCount > 1 then
       raise err_task_1;
     end if;

   exception when no_data_found then 
     if instr(act.act_task,'-AD') > 0 then 
       raise err_task_2;
     end if;
   end;
  end if;
  
EXCEPTION
WHEN err_task_1 THEN 
iErrMsg:='The subsequent task plan prefix should be same as first task activity and contain AD task plan.';
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
WHEN err_task_2 THEN
iErrMsg:='The first task plan cannot contaitn AD task plan.';
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;   
END;
