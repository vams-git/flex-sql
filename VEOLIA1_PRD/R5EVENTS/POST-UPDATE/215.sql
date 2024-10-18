declare 
  evt               r5events%rowtype;
  vNewStatus        r5events.evt_status%type;
  vOldStatus        r5events.evt_status%type;
  vTimeDiff         number;
  
  vSiteUserCode     varchar2(80);
  vWODesc           r5events.evt_desc%type;
  
  test_err          exception;
  iErrMsg           varchar2(400);   
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_org IN ('HWC','BEN','GSP','BAL') then
     if evt.evt_status in ('40PR') and nvl(evt.evt_class,' ') in ('CO', 'BD', 'OP', 'RF', 'RN', 'MO', 'CN', 'SE','PS') then
        --Check is parent WO status change?
         begin
            select ava_to,ava_from,timediff into vNewStatus,vOldStatus,vTimeDiff
            from (
            select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
            from r5audvalues,r5audattribs
            where ava_table = aat_table and ava_attribute = aat_code
            and   aat_table = 'R5EVENTS' and aat_column = 'EVT_STATUS'
            and   ava_table = 'R5EVENTS' 
            and   ava_primaryid = evt.evt_code
            and   ava_updated = '+'
            and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
            order by ava_changed desc
            ) where rownum <= 1;
         exception when no_data_found then 
            vNewStatus := null;
            return;
         end;
         if vOldStatus in ('25TP') then
            select obj_udfchar15 into vSiteUserCode
            from r5objects
            where obj_code = evt.evt_udfchar03 and obj_org = evt.evt_object_org;
            if vSiteUserCode is not null then
              vSiteUserCode := vSiteUserCode || '-';
              if evt.evt_desc not like vSiteUserCode||'%' then
                 vWODesc := substr(vSiteUserCode || evt.evt_desc,1,80);
                 update r5events e
                 set e.evt_desc = vWODesc
                 where e.rowid=:rowid
                 and e.evt_desc <> vWODesc;
              end if;
            end if;
         end if;
     end if;
  end if;
  
exception 
 when test_err then 
   RAISE_APPLICATION_ERROR (-20003,iErrMsg);  
 when others then       
   RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5EVENTS/Post Update/215');   
end;