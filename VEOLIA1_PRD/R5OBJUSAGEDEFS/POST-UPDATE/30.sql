declare 
  oud         r5objusagedefs%rowtype;
  vMetToGo    r5events.evt_meterdue%type;
  
  vNewValue       r5audvalues.ava_to%type;
  vOldValue       r5audvalues.ava_from%type;
  vTimeDiff       number;
  vColumn         r5audattribs.aat_column%type;
  
  cursor cur_wo(vObj varchar2,vObjOrg varchar2,vUom varchar2) is
  select evt_code,evt_meterdue
  from r5events
  where evt_object = vObj and evt_object_org =  vObjOrg and evt_metuom = vUOM
  and   evt_meterdue is not null
  and   evt_type ='PPM'
  and   evt_Status in ('25TP','40PR','35SB','53MH');

begin
  select * into oud from r5objusagedefs where rowid=:rowid;
  if nvl(oud.oud_totalusage,0) > 0 then
  begin
      select aat_column,ava_to,ava_from,timediff into vColumn,vNewValue,vOldValue,vTimeDiff
      from (
      select aat_column,ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5OBJUSAGEDEFS' and aat_column = 'OUD_TOTALUSAGE'
      and   ava_table = 'R5OBJUSAGEDEFS' 
      and   ava_primaryid = oud.oud_object and ava_secondaryid = oud.oud_object_org ||' '||oud.oud_uom
      and   ava_updated = '+'
      --and ava_inserted ='+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
      order by ava_changed desc
      ) where rownum <= 1;
          
      update r5events
      set    evt_udfnum07 = evt_meterdue - nvl(oud.oud_totalusage,0)
      where  evt_object = oud.oud_object and evt_object_org =  oud.oud_object_org and evt_metuom = oud.oud_uom
      and    evt_parent is null 
      and    evt_type = 'PPM'
      and    evt_Status in ('25TP','40PR','35SB','53MH')
      and    evt_meterdue is not null
      and    nvl(evt_udfnum07,0) <> nvl(evt_meterdue,0) - nvl(oud.oud_totalusage,0);
  exception when no_data_found then
     null;
  end;
  end if;
  /*for rec_wo in cur_wo(oud.oud_object,oud.oud_object_org,oud.oud_uom) loop
      vMetToGo := rec_wo.evt_meterdue - nvl(oud.oud_totalusage,0);
      update r5events
      set evt_udfnum07 = vMetToGo
      where evt_code = rec_wo.evt_code
      and   nvl(evt_udfnum07,0) <> nvl(vMetToGo,0);
  end loop;*/
exception   
when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objusagedefs/Update/30/'||substr(SQLERRM, 1, 500)) ; 
end;