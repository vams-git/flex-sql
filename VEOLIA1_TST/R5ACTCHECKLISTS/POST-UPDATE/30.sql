declare 
  ack             r5actchecklists%rowtype; 
  vTriggerValue   u5checklistsfollowup.tcf_value%type;
  vTriggerFlag    varchar2(1);
  
begin
  select * into ack from r5actchecklists where rowid=:rowid;
  if ack.ack_event is null then
    return;
  end if;
  begin
    select upper(tcf_value) into vTriggerValue 
    from u5checklistsfollowup
    where tcf_code = ack.ack_taskchecklistcode;
    
    vTriggerFlag := 'N';

  --and ack_completed = decode(vTriggerValue,'YES','+','-')
    if ack.ack_type = '01' then 
      if (vTriggerValue = 'YES' and ack.ack_completed ='+') then 
       vTriggerFlag := 'Y';
      end if;
    elsif ack.ack_type = '02' then
      if (vTriggerValue = 'YES' and ack.ack_yes ='+') or (vTriggerValue = 'NO' and ack.ack_no ='+') then
        vTriggerFlag := 'Y';
      end if;
    elsif ack.ack_type = '03' and ack.ack_finding = vTriggerValue then  
       vTriggerFlag := 'Y';
    end if;
    
    if vTriggerFlag = 'Y' then
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
   
    
  exception when no_data_found then
    null;
  end;
  
  

EXCEPTION
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5ACTCHECKLISTS/Post Update/30/'||substr(SQLERRM, 1, 500)) ; 
end;