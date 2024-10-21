declare 
  evt             r5events%rowtype; 
  vClientWOType   r5contactrecords.ctr_udfchar02%type;
  vObjDesc        r5objects.obj_desc%type;
  vFlag           varchar2(1);
  vCount          number;
  cursor cur_ack(vEvtCode varchar2) is 
  select distinct ack_act
  from r5actchecklists
  where ack_event =  vEvtCode;
  
begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') and evt.evt_org ='WBP' and evt.evt_status ='52DT' then
    begin
      select obj_desc into vObjDesc from r5objects where obj_code = evt.evt_object and obj_org = evt.evt_object_org;
      select ctr_udfchar02 into vClientWOType from r5contactrecords where ctr_event = evt.evt_code and ctr_org = evt.evt_org;

      
      for rec_ack in cur_ack(evt.evt_code) loop
          vFlag := 'N';
          if vObjDesc like '%NONE%' then
             vFlag := 'Y';
          else 
             select count(1) into vCount from r5actchecklists 
             where ack_event = evt.evt_code and ack_act = rec_ack.ack_act
             and   (vClientWOType = 'WATER' and ack_sequence = 44020 and ack_finding not in ('WSPM','WSRE','WSTP')) 
                or (vClientWOType = 'WASTEWATER' and ack_sequence = 45020 and ack_finding not in ('SWTP','SWPU'))
                or (vClientWOType = 'URBAN S/W' and ack_sequence = 45020 and ack_finding not in ('SWPM'));
             if vCount > 0 then
                vFlag := 'Y';
             end if;
          end if;
          if vFlag ='Y' then
             update r5actchecklists
             set    ack_requiredtoclose ='YES'
             where  ack_event= evt.evt_code
             and    ack_act = rec_ack.ack_act
             and    ack_sequence in (601000, 602000, 603000, 603500, 603510) 
             and    ack_requiredtoclose='NO';   
         else
            update r5actchecklists
             set    ack_requiredtoclose ='NO'
             where  ack_event= evt.evt_code
             and    ack_act = rec_ack.ack_act
             and    ack_sequence in (601000, 602000, 603000, 603500, 603510) 
             and    ack_requiredtoclose='YES'; 
         end if;
      end loop;
     
    exception when no_data_found then 
      null;
    end;
  end if; 
  
--EXCEPTION
 --  when others then
   --RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/195/'||substr(SQLERRM, 1, 500)) ;
end;