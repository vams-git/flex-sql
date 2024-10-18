declare 
  tra                r5transactions%rowtype;
  vCount             number;
  
  vReceiptTrans      r5translines.trl_trans%type;
  vReceiptTransLine  r5translines.trl_line%type;
  vOrder        r5orders.ord_code%type;
  vOrdLine      r5orderlines.orl_ordline%type;
  vOrlStatus    r5orderlines.orl_status%type;
  vRetnQty      r5translines.trl_qty%type;
  vTotalInvQty  r5invoicelines.ivl_invqty%type;
  vRecvQty      r5translines.trl_qty%type;
  
  iErrMsg            varchar2(500);
  err_validate       exception;
  
  cursor cur_trl(vTraCode varchar2) is 
  select distinct trl_order,trl_ordline,trl_order_org from r5translines
  where trl_trans = vTraCode;
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_status ='A' and tra.tra_type ='RETN' and tra.tra_routeparent is null then
    for rec_trl in cur_trl(tra.tra_code) loop
        select orl_order,orl_ordline,orl_status,
        nvl(orl_recvqty,0),nvl(orl_udfnum04,0)
        into   vOrder,vOrdLine,vOrlStatus,
        vRecvQty,vTotalInvQty
        from   r5orderlines orl
        where  orl_order = rec_trl.trl_order and orl_ordline = rec_trl.trl_ordline and orl_order_org = rec_trl.trl_order_org;

        --if vTotalInvQty = 0 and vOrlStatus ='CP' then  
         if vOrlStatus ='CP' then 
           update r5orderlines
           set orl_status='A',orl_active ='+'
           where orl_order = rec_trl.trl_order and orl_ordline = rec_trl.trl_ordline and orl_order_org = rec_trl.trl_order_org;
        end if;
    end loop;

  end if;
    
  
  
exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Update/250'||substr(SQLERRM, 1, 500)) ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;