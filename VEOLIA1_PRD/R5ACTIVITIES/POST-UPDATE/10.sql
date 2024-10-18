DECLARE 
  act          r5activities%rowtype;
  vOrg         r5organization.org_code%type;
  vClass       r5events.evt_class%type;
  vObject      r5objects.obj_code%type;
  vLocale      r5organization.org_locale%type;
  vType        r5events.evt_type%type;
  
  vCount       number;
  err_chk      exception;
  iErrMsg      varchar2(400); 
  iLang        r5users.usr_lang%type; 
BEGIN 
  select * into act from r5activities where rowid=:rowid;
  select evt_org,nvl(evt_class,'N'),evt_object,org_locale,evt_type
  into vOrg,vClass,vObject,vLocale,vType
  from r5events,r5organization
  where evt_code=act.act_event
  and   evt_org = org_code;
  
  if vType in ('JOB') then
     if (act.act_udfdate03 > o7gttime(vOrg)+1/48)--Service Interrupted
     or (act.act_udfdate04 > o7gttime(vOrg)+1/48)--Service Restored
     then
       iErrMsg:='Please note it is not possible to input date in the future. Please amend the records accordingly.';
       raise err_chk;
     end if;
  end if;
  
  --check only allow one activity for work order
  if vLocale = 'NZ' then
    
    if vOrg not in ('WBP') and vClass in ('BD','CO') then
      if act.act_hire ='-' and act.act_task is not null then
        select count(1) into vCount 
        from r5activities 
        where act_event=act.act_event
        and  act_hire='-'
        and  act_task is not null
        and rowid<>:rowid;
        if vCount > 0 then
          iErrMsg:='It is not possible to add another Work Order Activity with Task Plan for WO within this organization.';
          raise err_chk;
        end if;
     end if;
    end if;
    
      --check task plan  
  if  (vOrg not in ('WBP') and vClass in ('BD','CO'))
    or  (vOrg in ('WBP') and vClass in ('BD','CO','PS','RN')) then
    --validate task plan cannot applied on hired activity 
    if act.act_hire ='+' and act.act_task is not null then
       iErrMsg:='It is not possible to add another Work Order Activity with Task Plan for Hired Activity within this organizaton';
       raise err_chk;
    end if;
    --validate element with task plan
    if act.act_task is not null then
      select count(1) into vCount
      from   r5objects
      where (substr(obj_code,1,1) in ('E','K','1')
      or    (substr(obj_code,1,1) in ('3')
            and 
            (upper(obj_desc) like '%NONE%' 
           or upper(obj_desc) like '%NEW%' 
           or upper(obj_desc) like '%CANTFIND%')
           ))
      and  obj_code = vObject;
      if vCount = 0 then
         iErrMsg:='Task plan cannot be added for this WO Element';
         raise err_chk;
      end if;
    end if;
    --validate transaction vs task plan
      /*if act.act_task is not null then
       iErrMsg:='The task cannot be associated because transactions have been associated with it.';
      select count(1) into vCount from r5bookedhours where boo_event = act.act_event and boo_act = act.act_act;
        if vCount > 0 then
           raise err_chk;
        end if;
        select count(1) into vCount from r5translines where trl_event = act.act_event and trl_act = act.act_act;
        if vCount > 0 then
           raise err_chk;
        end if;
        select count(1) into vCount from r5toolusage where tou_event = act.act_event and tou_act = act.act_act;
        if vCount > 0 then
           raise err_chk;
        end if;
        select count(1) into vCount from r5requislines where rql_event = act.act_event and rql_act = act.act_act and rql_rstatus not in ('C','J');
        if vCount > 0 then
           raise err_chk;
        end if;
    end if;*/
  end if;
    
  end if;
 

EXCEPTION
WHEN err_chk THEN
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;  
END;
