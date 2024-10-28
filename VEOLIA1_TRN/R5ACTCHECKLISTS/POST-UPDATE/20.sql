declare 
  ack             r5actchecklists%rowtype; 
  vTask           r5taskchecklists.tch_task%type;
  vTaskRev        r5taskchecklists.tch_taskrev%type;
  
  cursor cur_ted(vTask nvarchar2,vRev number,vSequence number) is
  select tcd_dependforseq from U5CHECKLISTSDEPEND
  where  tcd_task=vTask and tcd_taskrev = vRev
  and tcd_sequence=vSequence;
begin
  select * into ack from r5actchecklists where rowid=:rowid;
  if ack.ack_event is null then
    return;
  end if;
  if ack.ack_type='02' then
 
     --dbms_output.put_line(TMP(I).ack_sequence);
     begin
       select tch_task,tch_taskrev
       into   vTask,vTaskRev
       from   r5taskchecklists
       where  tch_code =ack.ack_taskchecklistcode;
     exception when no_data_found then 
       return;
     end;
     
    for rec_ted in cur_ted(vTask,vTaskRev,ack.ack_sequence) loop
        --dbms_output.put_line('update');
       if ack.ack_yes ='+' then
         update r5actchecklists
         set    ack_requiredtoclose ='YES'
         where  ack_event= ack.ack_event
         and    ack_act = ack.ack_act
         and    ack_sequence = rec_ted.tcd_dependforseq
         and    ack_requiredtoclose='NO';
       else
         update r5actchecklists
         set    ack_requiredtoclose ='NO'
         where  ack_event=ack.ack_event
         and    ack_act =ack.ack_act
         and    ack_sequence = rec_ted.tcd_dependforseq
         and    ack_requiredtoclose ='YES';
       end if;
   end loop;
  end if;

EXCEPTION
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5ACTCHECKLISTS/Post Update/20/'||substr(SQLERRM, 1, 500)) ; 
end;