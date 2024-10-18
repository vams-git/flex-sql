declare 
  dkl       r5docklines%rowtype;
  
  vOrlType           r5orderlines.orl_type%type;
  vOrdQty            r5orderlines.orl_ordqty%type;
  vPrice             r5orderlines.orl_price%type;
  vOrderValue        r5orderlines.orl_price%type;
  vRecvQty           r5orderlines.orl_recvqty%type;
  vRecvValue         r5orderlines.orl_recvvalue%type;
  
  vTotalRecvQty      r5orderlines.orl_recvqty%type;
  
  vTolerancePer      number;
  vToleranceQty      r5orderlines.orl_recvqty%type;
  
  vStatus            varchar2(4);
  checkresult        varchar2(4);
  iErrMsg            varchar2(500);
  err_validated      exception;
  vReceiptQty        varchar2(50);
  
begin
  select * into dkl from r5docklines where rowid=:rowid;
  select dck_status into vStatus from r5dockreceipts where dck_code = dkl.dkl_dckcode;
  if dkl.dkl_linestatus in ('A') then
    /****1. Check number of decimal***********/
    vReceiptQty := to_char(dkl.dkl_countqty);
    if instr(vReceiptQty,'.') > 0 then
      if length(vReceiptQty) - instr(vReceiptQty,'.') > 3 then
         iErrMsg := 'Please note Receipting quantity or values in S/4 HANA can contains only 3 decimals. Please adjust your record accordingly and re-submit.';
         raise err_validated;
      end if;
    end if;
    /****2. Check Over Receipt Tolerance*******/
     begin
        select orl_type,orl_ordqty,orl_price,orl_ordqty * orl_price,nvl(orl_recvqty,0),nvl(orl_recvvalue,0)
        into   vOrlType,vOrdQty,vPrice,vOrderValue,vRecvQty,vRecvValue
        from   r5orderlines
        where  orl_order = dkl.dkl_order and orl_ordline = dkl.dkl_ordline 
        and orl_order_org = dkl.dkl_order_org ; -- modified vy Jacky on Sep-29
     exception when no_data_found then
       return;
     end;     
     vTotalRecvQty := vRecvQty; --+ dkl.dkl_countqty;

     if o7getorgoption('OVERRECV',dkl.dkl_order_org,checkresult )  = 'NO' then
         null;
     else
         begin
            select opa_desc into vTolerancePer
            from r5organizationoptions WHERE OPA_CODE='PORECVP' AND OPA_ORG = dkl.dkl_order_org;
         exception when no_data_found then
             vTolerancePer :=0;
         end;
         vToleranceQty :=  vOrdQty * to_number(vTolerancePer) * 0.01;
         if vTotalRecvQty - vOrdQty > vToleranceQty then
              iErrMsg := 'Receipt Qty. cannot be greater than the '||vTolerancePer||'% of order Qty. for part '||dkl.dkl_part ||' on the purchase order.';
              raise err_validated;
         end if; 
     end if;
   end if;
exception 
when err_validated then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5DOCKLINES/Post Update/200') ;
  -- RAISE_APPLICATION_ERROR ( -20001, substr(SQLCODE||SQLERRM, 1, 500)) ; 
end;