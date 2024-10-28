declare 
 ock   r5operatorchecklists%rowtype;
 iErrMsg      varchar2(400);
 val_err      exception;
 vCnt         number;
 
begin
  select count(1) into vCnt from r5operatorchecklists ock,r5objects,r5tasks
  where ock_object = obj_code and ock_object_org = obj_org
  and   ock_task = tsk_code and ock_taskrev = tsk_revision
  and   obj_obtype not in ('06EQ','07CP') and tsk_class = 'VCON'
  and   ock.rowid=:rowid;
  if vCnt > 0 then
     iErrMsg := 'Please select an equipment to be able to raise a fleet defect notification';
     raise val_err; 
  end if;

exception
when val_err then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
 RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;