declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;

  
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'OC01' then
     begin
       select count(1) into vCnt 
       from r5operatorchecklists o
       where o.ock_org = tkd.tkd_promptdata1
       and   o.ock_code = tkd.tkd_promptdata2
       and   o.ock_status = 'U';
       if vCnt > 0 then
          update r5operatorchecklists
          set ock_status ='CC',ock_rstatus ='CC'
          where ock_org = tkd.tkd_promptdata1
          and   ock_code = tkd.tkd_promptdata2;
       else
          iErrMsg := 'Operator checklist is not found or not in Unfinished Status';
          RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
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
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/160/' ||SQLCODE || SQLERRM) ;
end;
