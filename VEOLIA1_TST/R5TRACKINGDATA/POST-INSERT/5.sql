declare 
  tkd           r5trackingdata%rowtype;
  usr           r5users%rowtype;
  iErrMsg       varchar2(400);
  err_val       exception;
  

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans in ('USRE') then
    --select s5bookedhours.nextval into vBooCode from dual;
    begin
       select * into usr from r5users where usr_code = tkd.tkd_promptdata1;
       update r5users u set u.usr_externcode = tkd.tkd_promptdata2 where u.usr_code = tkd.tkd_promptdata1;
       o7interface.trkdel(tkd.TKD_TRANSID);
    exception when others then
      iErrMsg := 'User is not Found!';
      raise err_val;
    end;
  end if;
  
exception
   when no_data_found then 
    null;
  when err_val then
     RAISE_APPLICATION_ERROR(-20005, iErrMsg);
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/50/' ||SQLCODE || SQLERRM) ;
end;
