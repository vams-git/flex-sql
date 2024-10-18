declare 
  ack             r5actchecklists%rowtype; 
  vTskClass       r5classes.cls_code%type;
  vOrgDesc        r5organization.org_desc%type;
  vCnt            number;
begin
  select * into ack from r5actchecklists where rowid =:rowid;
  if ack.ack_rentity = 'OPCK' and ack.ack_sequence = 100 then
    begin
     select org_desc, tsk_class into vOrgDesc, vTskClass
     from   r5organization, r5tasks,r5operatorchecklists
     where  org_code = ack.ack_object_org
     and    tsk_code = ock_task and  tsk_revision = ock_taskrev
     and    ock_code = ack.ack_entitykey;
    exception when no_data_found then
      return;
    end;
    if vTskClass = 'CONA'then
       update r5actchecklists ack
       set    ack.ack_completed ='+',
       ack.ack_notes = 'Condition Assessment '|| vOrgDesc || ' - ' || to_char(sysdate,'DD-MON-YYYY')
       where  rowid =:rowid;
    end if; 
  end if;

exception when others then 
   RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5actchecklists/Post Insert/50/'||substr(SQLERRM, 1, 500)) ; 
end;