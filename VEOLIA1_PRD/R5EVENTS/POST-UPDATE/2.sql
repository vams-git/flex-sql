DECLARE
  evt           r5events%rowtype;
  obj           r5objects%rowtype;
  
  vPerDesc      r5personnel.per_desc%type;
  vAssignBy     r5personnel.per_code%type;
  vIsDateValid  r5organizationoptions.opa_desc%type;
  vCount        number;
  vCompleted    date;
  vStart        date;
  vUdfDate03    date;
  vUdfDate04    date;
  
  vNewValue       r5audvalues.ava_to%type;
  vOldValue       r5audvalues.ava_from%type;
  vTimeDiff       number;
  vColumn         r5audattribs.aat_column%type;
  vAdddays        varchar2(15);
  vAdddays_n      number;
  vSchEndDate     r5events.evt_schedend%type;
  
  vOrgUdfchar08    r5organization.org_udfchar08%type;
  vPriority        number;
  iSepChar         varchar2(1)  := '/';
  
  vRejComment      varchar2(4000);
  vRejLine         number;
  vRejReason       r5events.evt_rejectreason%type;
  vRejReasonLen    number;
  
  
  iErrMsg       varchar2(400);
  err_chk       exception;
BEGIN
  -- This flex is replace R5EVENTS Trigger U5PREUPDEVENTS
  -- select the current WO 
  select * into evt from r5events where rowid=:rowid; --='1005379173';--
  if evt.evt_type not in ('PPM','JOB') then 
     return;
  end if;
  
  --replace Trigger U5PREUPDEVENTS 
  /*--copy from evt_udfchar29 to evt_mrc
  if :new.evt_udfchar29 is not null then
     :new.evt_mrc := :new.evt_udfchar29;
  end if;*/
  select case when evt.evt_person is null then null else r5o7.o7get_desc('EN','PERS', evt.evt_person,'','') end
  into vPerDesc from dual;
  if nvl(evt.evt_udfchar31,' ') <> nvl(vPerDesc,' ') then
     update r5events 
     set evt_udfchar31 = vPerDesc
     where evt_code = evt.evt_code; 
     
     --UPDATE BY CXU on 202109 update 
     if evt.evt_org in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW') then
       begin
       select per_code into vAssignBy
       from r5personnel per,r5schedgroups
       where per.per_user = o7sess.cur_user and per.per_org = evt.evt_org
       and   per.per_code = scg_code;
       if nvl(vAssignBy,' ') <> nvl(evt.EVT_SCHEDGRP,' ') then
           update r5events 
           set EVT_SCHEDGRP = vAssignBy
           where evt_code = evt.evt_code;  
       end if;
       exception when no_data_found then
         null;
       end; 
      end if;
  end if;


  if nvl(evt.evt_udfchar29,' ') <> nvl(evt.evt_mrc,' ') then
     if evt.evt_org in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW','FCG') and evt.evt_mrc is not null then
        update r5events 
        set evt_udfchar29 = evt.evt_mrc 
        where evt_code = evt.evt_code;
     end if;
     if evt.evt_org not in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW','FCG') and evt.evt_udfchar29 is not null then
        update r5events 
        set evt_mrc = evt.evt_udfchar29 
        where evt_code = evt.evt_code;
     end if;
  end if;
  
  --update evt_schedend by priority and org_udfchar08
  if nvl(evt.evt_priority,'*') <> '*' then
      begin
          select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
          from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5EVENTS' and aat_column = 'EVT_PRIORITY'
          and   ava_table = 'R5EVENTS' 
          and   ava_primaryid = evt.evt_code
          and   ava_updated = '+'
          --and ava_inserted ='+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
          order by ava_changed desc
          ) where rownum <= 1;
      exception when no_data_found then 
        vNewValue := null;
      end;

      begin
       select nvl(org_udfchar08,' ') into vOrgUdfchar08
       from r5organization where org_code = evt.evt_org;
      exception when no_data_found then
        vOrgUdfchar08 := ' ';
      end;
      
      if nvl(vNewValue,' ') <> ' ' and nvl(vOrgUdfchar08, ' ') <> ' ' then
        select to_number(decode(evt.evt_priority,null,0,'*',0,evt.evt_priority))
        into vPriority from dual;
        --v_priority := to_number(decode(:new.evt_priority,null,0,'*',0,:new.evt_priority));
        select code into vAdddays from (
        select regexp_substr(vOrgUdfchar08,'[^' || iSepChar || ' ]+', 1, level) as code,
        level from dual
        where level = vPriority+1
        connect by regexp_substr(vOrgUdfchar08,'[^/' || iSepChar || ']+', 1, level) is not null
        );
        begin
          if vAdddays is not null then
            vAdddays_n := to_number(vAdddays);
            --Schedule End Date = Schedule Start Date + ORG_UDFCHAR08
            vSchEndDate := evt.evt_target + vAdddays_n;
            if (evt.evt_schedend is null or vSchEndDate <> evt.evt_schedend) then
                update r5events 
                set evt_schedend = vSchEndDate 
                where evt_code = evt.evt_code;
            end if;
          end if;
        exception when others then 
          null;
        end;
      end if;
  end if;
  
  --Copy equipment UDF01-UDF16 to work order when status change/equipment change
  begin
      select aat_column,ava_to,ava_from,timediff into vColumn,vNewValue,vOldValue,vTimeDiff
      from (
      select aat_column,ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5EVENTS' and aat_column in ('EVT_OBJECT','EVT_STATUS')
      and   ava_table = 'R5EVENTS' 
      and   ava_primaryid = evt.evt_code
      and   ava_updated = '+'
      --and ava_inserted ='+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
      order by ava_changed desc
      ) where rownum <= 1;
  exception when no_data_found then 
    vNewValue := null;
  end;
  if vNewValue is not null then
      select * into obj from r5objects where obj_code = evt.evt_object and obj_org = evt.evt_object_org;
      update r5events set
      evt_udfchar01 = obj.obj_udfchar01,
      evt_udfchar02 = obj.obj_udfchar02,
      evt_udfchar03 = obj.obj_udfchar03,
      evt_udfchar04 = obj.obj_udfchar04,
      evt_udfchar05 = obj.obj_udfchar05,
      evt_udfchar06 = obj.obj_udfchar06,
      evt_udfchar07 = obj.obj_udfchar07,
      evt_udfchar08 = obj.obj_udfchar08,
      evt_udfchar09 = obj.obj_udfchar09,
      evt_udfchar10 = obj.obj_udfchar10,
      evt_udfchar11 = obj.obj_udfchar11,
      evt_udfchar12 = obj.obj_udfchar12,
      evt_udfchar13 = obj.obj_udfchar13,
      evt_udfchar14 = obj.obj_udfchar14,
      evt_udfchar15 = obj.obj_udfchar15,
      evt_udfchar16 = obj.obj_udfchar16,
      evt_udfchar36 = obj.obj_udfchar26,
      evt_udfchar46 = obj.obj_udfchar46, --REGION CODE
      evt_udfchar47 = obj.obj_udfchar47, --REGION DESC
      evt_workaddress = nvl(evt_workaddress,obj.obj_udfnote02)
      where evt_code = evt.evt_code
      and (
      nvl(evt_udfchar01,' ')<>nvl(obj.obj_udfchar01,' ')
      or nvl(evt_udfchar02,' ')<>nvl(obj.obj_udfchar02,' ')
      or nvl(evt_udfchar03,' ')<>nvl(obj.obj_udfchar03,' ')
      or nvl(evt_udfchar04,' ')<>nvl(obj.obj_udfchar04,' ')
      or nvl(evt_udfchar05,' ')<>nvl(obj.obj_udfchar05,' ')
      or nvl(evt_udfchar06,' ')<>nvl(obj.obj_udfchar06,' ')
      or nvl(evt_udfchar07,' ')<>nvl(obj.obj_udfchar07,' ')
      or nvl(evt_udfchar08,' ')<>nvl(obj.obj_udfchar08,' ')
      or nvl(evt_udfchar09,' ')<>nvl(obj.obj_udfchar09,' ')
      or nvl(evt_udfchar10,' ')<>nvl(obj.obj_udfchar10,' ')
      or nvl(evt_udfchar11,' ')<>nvl(obj.obj_udfchar11,' ')
      or nvl(evt_udfchar12,' ')<>nvl(obj.obj_udfchar12,' ')
      or nvl(evt_udfchar13,' ')<>nvl(obj.obj_udfchar13,' ')
      or nvl(evt_udfchar14,' ')<>nvl(obj.obj_udfchar14,' ')
      or nvl(evt_udfchar15,' ')<>nvl(obj.obj_udfchar15,' ')
      or nvl(evt_udfchar16,' ')<>nvl(obj.obj_udfchar16,' ')
      or nvl(evt_udfchar36,' ')<>nvl(obj.obj_udfchar26,' ')
      or nvl(evt_udfchar46,' ')<>nvl(obj.obj_udfchar46,' ') --region code
      or nvl(evt_udfchar47,' ')<>nvl(obj.obj_udfchar47,' ') --region desc
      or nvl(evt_workaddress,' ')<>nvl(nvl(evt_workaddress,obj.obj_udfnote02),' ')
      );    
  end if;
  
  if vNewValue is not null and vColumn ='EVT_STATUS' then  
     update r5events
     set evt_udfdate07 = o7gttime(evt.evt_org),
     evt_udfchar32 = o7sess.cur_user
     where evt_code = evt.evt_code
     and (
     nvl(evt_udfdate07,to_date('1900-01-01','YYYY-MM-DD')) <> o7gttime(evt.evt_org)
     or nvl(evt_udfchar32,' ') <> o7sess.cur_user
     );
   
   
   --remove "Reject Details" comment here
   if vOldValue = '15TV' and vNewValue <> '20RJ' then
     begin
      select add_line,add_text into vRejLine,vRejComment from
      (select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)as add_text
      from r5addetails
      where add_entity='EVNT' and add_code=evt.evt_code and add_lang = 'EN')
      where add_text like 'Reject Reason Details%'
      and   rownum<=1;
      
      delete from r5addetails
          where add_entity='EVNT' and add_code=evt.evt_code and add_lang = 'EN'
          and   add_line = vRejLine;
     exception when no_data_found then
          vRejLine := 0;  
     end;
   end if;
   -- if vOldValue = '15TV' then
  end if; 
  --if vNewValue is not null and vColumn ='EVT_STATUS' then  
  
  if vNewValue is not null --and vColumn ='EVT_OBJECT'
  then
     begin
        select aat_column,ava_to,ava_from,timediff into vColumn,vNewValue,vOldValue,vTimeDiff
        from (
        select aat_column,ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
        from r5audvalues,r5audattribs
        where ava_table = aat_table and ava_attribute = aat_code
        and   aat_table = 'R5EVENTS' and aat_column in ('EVT_PERSON')
        and   ava_table = 'R5EVENTS' 
        and   ava_primaryid = evt.evt_code
        and   ava_updated = '+'
        --and ava_inserted ='+'
        and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
        order by ava_changed desc
        ) where rownum <= 1;
    exception when no_data_found then 
       vOldValue := null;
    end;
    if vOldValue is not null and vOldValue <> nvl(evt.evt_person,' ') then
      update r5events
      set evt_person =  vOldValue
      where evt_code = evt.evt_code;
      --iErrMsg := vOldValue;
      --raise err_chk;
    end if;
  end if;

EXCEPTION
WHEN err_chk THEN
  RAISE_APPLICATION_ERROR ( -20003, iErrMsg);
/*WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/1/'||substr(SQLERRM, 1, 500));*/
END;
