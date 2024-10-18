declare 
  tra                r5transactions%rowtype;
  vCount             number;
  
  vReceiptTrans      r5translines.trl_trans%type;
  vReceiptTransLine  r5translines.trl_line%type;
  vOrder        r5orders.ord_code%type;
  vOrdLine      r5orderlines.orl_ordline%type;
  vRetnQty      r5translines.trl_qty%type;
  vTotalInvQty  r5invoicelines.ivl_invqty%type;
  vRecvQty      r5translines.trl_qty%type;
  
  iErrMsg            varchar2(500);
  err_validate       exception;
  
  cursor cur_trl(vTraCode varchar2) is 
  select * from r5translines
  where trl_trans = vTraCode;
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_status ='A' and tra.tra_type ='RETN' and tra.tra_routeparent is null then
    for rec_trl in cur_trl(tra.tra_code) loop
       vRetnQty := nvl(rec_trl.trl_origqty,rec_trl.trl_qty);
       select orl_order,orl_ordline,
       nvl(orl_recvqty,0) + abs(vRetnQty),
       nvl(orl_udfnum04,0)
       into   vOrder,vOrdLine,
       vRecvQty,
       vTotalInvQty
       from   r5orderlines orl
       where  orl_order = rec_trl.trl_order and orl_ordline = rec_trl.trl_ordline and orl_order_org = rec_trl.trl_order_org;
      -- iErrMsg:= 'vRetnQty:'||vRetnQty||' vRecvQty:'||vRecvQty||' vTotalInvQty:'||vTotalInvQty;
       --raise err_validate;
       if abs(vRetnQty) > vRecvQty - vTotalInvQty  then
          iErrMsg := 'Can not return parts '|| rec_trl.trl_part ||' due to PO line has been invoiced Qty: '|| vTotalInvQty;
          raise err_validate;
       end if;
    end loop;
  end if;
    
  
 
exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Update/220'||substr(SQLERRM, 1, 500)) ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 

end;