DECLARE 
  act          r5activities%rowtype;
  evt          r5events%rowtype;
  
  vNewValue    r5audvalues.Ava_To%type;
  vOldValue    r5audvalues.ava_from%type;
  vTimeDiff    number;
  vMECEst      r5activities.act_udfnum01%type;
  vMECCount    number;

  
BEGIN 
   select * into act from r5activities where rowid=:rowid;
   select * into evt from r5events where evt_code = act.act_event;
   if evt.evt_jobtype ='MEC' then 
      return;
   end if;
   
   --if evt.evt_type = 'PPM' then
       --Check is ACT_EST updated by insert flex, if yes return
       begin
          select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
           from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5ACTIVITIES' and aat_column = 'ACT_EST'
          and   ava_table = 'R5ACTIVITIES' 
          and   ava_primaryid = act.act_event
          and   ava_secondaryid = act.act_act
          and   (ava_inserted = '+')
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
          order by ava_changed desc
          ) where rownum <= 1;
          return;
       exception when no_data_found then 
         null;
       end;
       
       begin
          select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
           from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5ACTIVITIES' and aat_column = 'ACT_EST'
          and   ava_table = 'R5ACTIVITIES' 
          and   ava_primaryid = act.act_event
          and   ava_secondaryid = act.act_act
          and   (ava_updated= '+')
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
          order by ava_changed desc
          ) where rownum <= 1;
       exception when no_data_found then 
         return;
       end;
       
       /*if nvl(act.act_udfchkbox01,'-') = '-' then
          vMECEst := act.act_est;
       end if;
       */
       
       --if act.act_udfchkbox01 = '+' then
          vMECEst := act.act_est;
          select count(1) into vMECCount
          from r5events 
          where evt_parent = evt.evt_code
          and evt_jobtype = 'MEC';
          if vMECCount >  0 then
             vMECEst := round(act.act_est/vMECCount,2);
          end if;
       --end if;
       
       update r5activities 
       set act_udfnum01 = vMECEst
       where rowid=:rowid
       and   nvl(act_udfnum01,0) <> vMECEst;
   --end if;
   
       --Update flag for manual work order, get no. of MEC WOs. 
       if evt.evt_type = 'JOB' then
          select count(1) into vMECCount 
          from r5events 
          where evt_parent = evt.evt_code and evt_jobtype = 'MEC';
          if vMECCount > 0 then
             update u5vucost set evo_recalcesthr ='+',evo_esthrcalculated='-' where evo_event = evt.evt_code;
          end if;
       end if;
   
   
  
EXCEPTION
    WHEN OTHERS THEN  Raise_application_error (-20003,'Error in Flex R5ACTIVITIES/Post Update/21/'||Substr(SQLERRM, 1, 500));
END;
