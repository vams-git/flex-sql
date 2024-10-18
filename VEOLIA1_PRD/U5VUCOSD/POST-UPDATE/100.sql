declare 
  ucd   u5vucosd%rowtype;
  cursor evo is
  select * from u5vucost where  evo_recalcesthr = '+'; 

  recs NUMBER := 0;
  
  PROCEDURE calc(event VARCHAR2,irecalcesthrtotal varchar2) IS
  
  vMECEst      r5activities.act_udfnum01%type;
  vMECCount    number;
  vtotalactest r5activities.act_est%type;
  vtotalmecest r5activities.act_udfnum01%type;
  
  vMsg varchar2(255);
    
  cursor act(ievt varchar2) is 
  select act_event,act_act,act_est,act_udfnum01,act_udfchkbox01
  from r5activities
  where act_event = ievt;
  
  BEGIN
    
      select count(1) into vMECCount
      from r5events 
      where evt_parent = event
      and evt_jobtype = 'MEC';
      
      for rec_act in act(event) loop
         vMECEst := rec_act.act_est;
         if vMECCount >  0 then
             vMECEst := round(rec_act.act_est/vMECCount,2);
         end if;
         update r5activities 
         set act_udfnum01 = vMECEst
         where act_event = rec_act.act_event and act_act = rec_act.act_act
         and   nvl(act_udfnum01,-9999) <> vMECEst;
         
         update r5activities 
         set act_udfnum01 = vMECEst
         where act_event in (select evt_code from r5events where evt_parent = event and evt_jobtype ='MEC')
         and   act_act = rec_act.act_act
         and   nvl(act_udfnum01,-9999) <> vMECEst; 
     end loop;
     
     if nvl(irecalcesthrtotal,'-') = '+' then
        select sum(nvl(act_est, 0)),sum(nvl(act_udfnum01, 0))
        into   vtotalactest,vtotalmecest
        from   r5activities,r5events
        where  act_event = evt_code 
        and    evt_code = event;
        
        update r5events set evt_udfnum04 = vtotalactest 
        where evt_code = event 
        and nvl(evt_udfnum04,-9999) <> nvl(vtotalactest,-9999);
        
        update r5events set evt_udfnum04 = vtotalmecest
        where evt_code in (select evt_code from r5events where evt_parent = event and evt_jobtype ='MEC') 
        and nvl(evt_udfnum04,-9999) <> nvl(vtotalmecest,-9999);

     end if;
         
     update u5vucost set 
     evo_recalcesthr = '-',
     evo_recalcesthrtotal = '-',
     evo_esthrcalculated = '+',
     evo_error ='-',evo_updated = sysdate
     where evo_event = event;
  exception when others then 
    vMsg := substr(SQLERRM, 1, 255);
    update u5vucost set evo_error = '+',evo_errormsg = vMsg,evo_updated = sysdate where evo_event = event;   
  END calc;
 
  
begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 10 and ucd.ucd_recalccost = '+' then
  recs := 0;
  for i IN evo loop
      recs := recs + 1;
      calc( i.evo_event,i.evo_recalcesthrtotal );
      IF recs > 1000 THEN
          RETURN;
      END IF;
  end loop;
  update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;

end;
