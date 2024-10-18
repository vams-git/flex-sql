declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  vNewStatus    r5invoices.inv_status%type;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'RU01' then
     begin
       select count(1) into vCnt from U5WUSVRE
       where WUS_SESSIONID = tkd.tkd_promptdata1
       and   WUS_ORG = tkd.tkd_promptdata2
       and   WUE_EVENT = tkd.tkd_promptdata3;
       
       if vCnt = 0 then
         insert into U5WUSVRE
         (WUS_SESSIONID,WUS_ORG,WUE_EVENT,WUE_WODESC,WUE_ERPREF)
         values
         (tkd.tkd_promptdata1,tkd.tkd_promptdata2,tkd.tkd_promptdata3,tkd.tkd_promptdata4,tkd.tkd_promptdata5);
       end if;
     
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
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/140/' ||SQLCODE || SQLERRM) ;
end;
