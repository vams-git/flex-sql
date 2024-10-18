DECLARE 
  act          r5activities%rowtype;
  evt          r5events%rowtype;
  
  vParEst      r5activities.act_est%type;
  vMecEst      r5activities.act_udfnum01%type;
  vMecCount    number;
  
  iErrMsg     varchar2(400);
  err         exception; 

BEGIN 
   select * into act from r5activities where rowid=:rowid;
   select * into evt from r5events where evt_code = act.act_event;
   if evt.evt_jobtype = 'MEC' then
      return;
   end if;
   if evt.evt_rstatus <> 'R' then 
      return;
   end if;
   
   --Inserting For PM Wrok order,  get nb.of equipment in route 
   if evt.evt_type = 'PPM' and evt.evt_ppopk is not null then
       select count(rob_object) into vMecCount
       from   r5ppmobjects,r5routes,r5routobjects
       where  ppo_route = rou_code
       and    rou_code = rob_route and rou_revision = rob_revision
       and    rou_revstatus ='A'
       and    ppo_pk = evt.evt_ppopk;
   end if;
   
   --Inserting for mp work order, get no. of equipment in route 
   if evt.evt_type = 'PPM' and evt.evt_psqpk is not null then
      select count(rob_object) into vMecCount
      from   r5patternequipment p,r5routes,r5routobjects
       where  p.peq_route = rou_code
       and    rou_code = rob_route and rou_revision = rob_revision
       and    rou_revstatus ='A'
       and    p.peq_mp = evt.evt_mp and p.peq_mp_org = evt.evt_mp_org
       and    p.peq_object = evt.evt_object and p.peq_object_org = evt.evt_object_org;
   end if;
   
   if evt.evt_type = 'JOB' then
      select count(1) into vMECCount
      from r5events 
      where evt_parent = evt.evt_code
      and evt_jobtype = 'MEC';
   end if;
   
   
   --set default value of est hours and mec est hours
   vParEst := act.act_est;
   vMecEst := act.act_est;
 
   if vMecCount > 0 then
      --when act_udfchkbox01 is not tickecd, parent wo est hours = ppa_est, mec wo est hours = ppa_est/no.of equipment
      if nvl(act.act_udfchkbox01,'-') = '-' then
         vParEst := act.act_est;
         vMecEst := round(act.act_est/vMecCount,2);
      end if;
       --when act_udfchkbox01 is not ticked, parent wo est hours = ppa_est * no.of equipment, mec wo est hours = ppa_est
      if nvl(act.act_udfchkbox01,'-') = '+' then
         vParEst := round(act.act_est * vMecCount,2);
         vMecEst := act.act_est;
      end if;
   end if;
   
   update r5activities
   set act_est = vParEst,
       act_udfnum01 = vMecEst
   where rowid=:rowid
   and (nvl(act_udfnum01,0) <> nvl(vMecEst,0)
   or nvl(act_est,0) <>  nvl(vParEst,0));
   
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
    WHEN OTHERS THEN  Raise_application_error (-20003,'Error in Flex R5ACTIVITIES/Post Insert/20/'||Substr(SQLERRM, 1, 500));
END;