declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'UU01' then
     begin
       update r5users
       set usr_udfchar05 = tkd.tkd_promptdata2
       where usr_code = tkd.tkd_promptdata1;
     
     exception when err_val then
        RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
     end;
         
     --delete from r5trackingdata where rowid=:rowid;
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  
exception
  when no_data_found then 
    null;
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/130/' ||SQLCODE || SQLERRM) ;
end;
