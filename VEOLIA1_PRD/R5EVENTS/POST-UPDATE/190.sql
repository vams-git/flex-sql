declare 
  evt               r5events%rowtype; 
  vMinAct           r5actchecklists.ack_act%type;
  vFinding          r5actchecklists.ack_finding%type;
  
begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') and evt.evt_org ='WBP' and evt.evt_status in('50SO','51SO') then
    begin
     select min(ack_act) into vMinAct
     from r5actchecklists where ack_event = evt.evt_code;
     
     select ack_finding into vFinding 
     from r5actchecklists 
     where ack_event = evt.evt_code and ack_act = vMinAct
     and   ack_sequence = 204511;
     
     if  vFinding in ('SPOV') then 
         update r5actchecklists
         set    ack_requiredtoclose ='YES'
         where  ack_event= evt.evt_code
         and    ack_act = vMinAct
         and    ack_sequence = 600000 
         and    ack_requiredtoclose='NO'; 
     end if;
     
        
    exception when no_data_found then 
      null;
    end;
  end if; 
  
EXCEPTION
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/190/'||substr(SQLERRM, 1, 500)) ;
end;