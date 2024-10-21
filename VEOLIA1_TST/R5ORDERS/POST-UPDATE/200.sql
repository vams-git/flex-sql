--Update pr Status 
--Update PO status when PO is update to completed invoiced.
declare 
  ord          r5orders%rowtype;
  
  vLineCnt        number;
  vInvoiceLineCnt number;
  --vNewStatus   varchar2(30);
  vReqCode       r5requisitions.req_code%type;
  
  vErrMsg        varchar2(400);
  err_val        exception;
  
 CURSOR curs_orl(vOrdCode varchar2) IS
 SELECT * FROM r5orderlines
 WHERE orl_order = vOrdCode;
 
begin
   select * into ord from r5orders where rowid=:rowid;
   
   /*** PO New Version is not allowed *****/
  if ord.ord_status ='U' and ord.ord_revision > 1 then 
      vErrMsg := 'PO is approved and not allowed to changed.';
      raise err_val; 
   end if;
   /**1.Update Order Line Status***/
  /*if ord.ord_status in ('CP') then
   for rec_orl in curs_orl(ord.ord_code) loop
       update r5orderlines
       set    orl_status  = ord.ord_Status,
              orl_rstatus = ord.ord_rStatus,
              orl_active = decode(ord.ord_Status,'CP','-','A','+',orl_active)
       where  orl_order = rec_orl.orl_order and orl_ordline = rec_orl.orl_ordline
       and    orl_status <> ord.ord_status
      and     nvl(decode(orl_type,'SF',orl_price,orl_ordqty),0) > nvl(decode(orl_type,'SF',orl_recvvalue,orl_recvqty),0);
   end loop;
  end if;*/
  
  
  /**2.Update Releated Requisition Header****
   CP: Completed
   RC: Completed Received
   RP: Partically Received
   RI: Completed Invoiced
   ******************************************/
   --if ord.ord_status in ('CP','RC','RP','RI') then
   if ord.ord_status in ('A','RP') then
     begin
     select orl_req into vReqCode from r5orderlines where orl_order = ord.ord_code and orl_order_org = ord.ord_org and rownum <= 1;
     
     update r5requisitions
     set req_status =  ord.ord_status
     where req_code =  vReqCode--ord.ord_udfchar29 
     and req_org = ord.ord_org
     and req_status <> ord.ord_status;
    exception when no_data_found then
     null;
     end; 
   end if;
 
exception 
  when err_val then
       RAISE_APPLICATION_ERROR ( -20003, vErrMsg) ; 
  when others then
       RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5ORDERS/Post Update/200') ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; *
end;
