declare 
  ack             r5actchecklists%rowtype; 
  vOrg            r5organization.org_code%type;
  cOrg            number;
  vErr            exception;
begin
  select * into ack from r5actchecklists where rowid=:rowid;--ACK_EVENT = '1005348714' AND ACK_ACT = 11 AND ACK_SEQUENCE = 199;
  
  if ack.ack_event is null then
    return;
  end if;
  
  begin
      select evt_org into vOrg from r5events where evt_code = ack.ack_event;
  exception when no_data_found then
    return;
  end;

  select count(1) into cOrg from r5organization where org_code = vOrg and org_udfchar10 like '%Fleet%';
  
  if cOrg = 0 then
      if ack.ack_type ='01' and ack.ack_requiredtoclose ='YES' and ack.ack_notes is null and ack.ack_updatedby = o7sess.cur_user then
          raise vErr;
      end if;
      if ack.ack_type ='03' and upper(ack.ack_finding) = 'OTHE'  and ack.ack_notes is null and ack.ack_updatedby = o7sess.cur_user then
         raise vErr;
      end if;
   end if; 

EXCEPTION
   WHEN vErr then
   RAISE_APPLICATION_ERROR ( -20003,'Please input a note comment for this checklist item') ;
   when others then
   RAISE_APPLICATION_ERROR (  -20003,'Error in Flex R5ACTCHECKLISTS/Post Update/10/'||substr(SQLERRM, 1, 500)) ; 
end;