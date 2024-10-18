declare
   add        r5addetails%rowtype;
   
   vGroup     r5users.usr_group%type;
   vStatus    r5events.evt_status%type;
   iErrMsg    varchar2(400);
   err_val    exception;
   
begin
   select * into add from r5addetails where rowid=:rowid;
   select usr_group into vGroup from r5users where usr_code = o7sess.cur_user;
   if vGroup in ('VNZ-NOP1','VNZ-NOP2') then
      if add.add_entity = 'EVNT' then
         select evt_status into vStatus from r5events where evt_code = add.add_code;
         if vStatus in ('50SO','51SO','55CA') then 
            iErrMsg := 'You are not authorized to update work order when status is Sign Off or Cost Assigned.';
            raise err_val;
         end if;
      end if;
   end if;

exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
    RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5addetails/Post Insert/60' ||SQLCODE || SQLERRM);
end;