declare
   orl              r5orderlines%rowtype;
   vInvoicePaidQty  r5orderlines.orl_udfnum05%type;
   vReceiptQty      r5orderlines.orl_recvvalue%type;
   vOrderQty        r5orderlines.orl_ordqty%type;
   vInvoicecQty     r5orderlines.orl_udfnum04%type;
   vOrlActive       r5orderlines.orl_active%type;
   
   vNewValue        r5audvalues.ava_from%type;
   vOldValue        r5audvalues.ava_from%type;
   vNewStatus       r5orderlines.orl_status%type;
   vOldStatus       r5orderlines.orl_status%type;
   vTimeDiff        number;
   
   vActive          r5orderlines.orl_active%type;
   vTrans           VARCHAR2(4);
   vIONTransID      NUMBER;
   vSource          VARCHAR2(10);
   vDestination     VARCHAR2(10);
   vorlxml          clob;
   
   vErrMsg           varchar2(4000);
   err_chk           exception;

begin
    select * into orl from r5orderlines where rowid=:rowid;
    --Copy Invoice Paid Qty to UDFNUM05
    select decode(orl.orl_type,'SF',orl.orl_invvalue,orl.orl_invqty) into vInvoicePaidQty from dual;
    if nvl(orl.orl_udfnum05,0) <> nvl(vInvoicePaidQty,0) then
       update r5orderlines
       set orl_udfnum05 = vInvoicePaidQty
       where rowid = :rowid;
    end if;
    
    select nvl(decode(orl.orl_type,'SF',orl.orl_recvvalue,orl.orl_recvqty),0),
           nvl(decode(orl.orl_type,'SF',orl.orl_price,orl.orl_ordqty),0),
           nvl(orl.orl_udfnum04,0)
    into vReceiptQty,vOrderQty,vInvoicecQty from dual; 
    
    if nvl(vReceiptQty,0)>0 and nvl(vReceiptQty,0) >=  nvl(vOrderQty,0) then
       if orl.orl_status  = 'A' then
          update r5orderlines
          set orl_status = 'CP',
              orl_udfchkbox01 ='+'
          where rowid =:rowid;
       end if;
    else 
       if nvl(orl.orl_udfchkbox01,'-') not in ('-') then
          update r5orderlines
          set orl_udfchkbox01 ='-'             
          where rowid =:rowid;
       end if;
    end if;
    
    
    --revert to A for service item 
    /* if nvl(vReceiptQty,0) < nvl(vOrderQty,0) --and vInvoicecQty = 0 
       and orl.orl_type like 'S%'  then
        if orl.orl_status  = 'CP' then
          update r5orderlines
          set orl_status = 'A',
              orl_udfchkbox01 ='-',
              orl_active = '+'
          where rowid =:rowid;
        end if;
     end if;*/
     /*if orl.orl_type like 'S%' and orl.orl_status  = 'CP' and nvl(vReceiptQty,0) < nvl(vOrderQty,0) then
         begin
          select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
           from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5ORDERLINES' and aat_column = 'ORL_RECVVALUE'
          and   ava_table = 'R5ORDERLINES' 
          and   ava_primaryid = orl.orl_order
          and   ava_secondaryid = orl.orl_order_org ||' '||orl.orl_ordline
          and   ava_updated = '+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
          order by ava_changed desc
          ) where rownum <= 1;
        exception when no_data_found then 
          vNewValue := null;
          vOldValue := null;
        end;
        if nvl(vNewValue,' ') <> nvl(vOldValue,' ') then 
            update r5orderlines
            set orl_status = 'A',
                orl_udfchkbox01 ='-',
                orl_active = '+'
            where rowid =:rowid;
        end if;
     end if;  */
     
     if orl.orl_status in ('CAN','CP','A') then
         select decode(orl.orl_status,'A','+','-') into vOrlActive from dual;
         update r5orderlines
         set orl_active = vOrlActive
         where rowid = :rowid
         and nvl(orl_active,'-') <> nvl(vOrlActive,'-');

         update r5requislines
         set rql_status = orl.orl_status,rql_active = vOrlActive
         where rql_req = orl.orl_req and rql_reqline = orl.orl_reqline
       and (rql_status <> orl.orl_status or rql_active <> vOrlActive); 
     end if;
     
     --validate is status change
     --Check is Status Update ?
    begin
      select ava_to,ava_from,timediff into vNewStatus,vOldStatus,vTimeDiff
       from (
      select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5ORDERLINES' and aat_column = 'ORL_STATUS'
      and   ava_table = 'R5ORDERLINES' 
      and   ava_primaryid = orl.orl_order
      and   ava_secondaryid = orl.orl_order_org ||' '||orl.orl_ordline
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
      order by ava_changed desc
      ) where rownum <= 1;
    exception when no_data_found then 
      vNewStatus := null;
      vOldStatus := null;
    end;
    
    if nvl(vOldStatus,' ') <> nvl(vNewStatus,' ') then 
       if orl.orl_status = 'CAN' and vReceiptQty > 0 then 
          vErrMsg :='PO line has been receipted, cannot change to Cancelled.';
          raise err_chk;
       end if;
       if orl.orl_status = 'CP' and vReceiptQty = 0 then
         vErrMsg :='PO line has not been receipted, cannot change to Completed.';
         raise err_chk;
       end if;
       if vOldStatus ='CP' and orl.orl_status = 'A' then
         if vReceiptQty >= vOrderQty then 
           vErrMsg := 'PO line has been fully receipted, cannot change to Approved.';
           raise err_chk;
         end if;
         /*if nvl(:new.orl_udfnum04,0) > 0 then 
            vErrMsg :='PO line has been invoiced, cannot change to Approved.';
            raise err_chk;
         end if;*/
       end if;
      
    end if; --endindg status change 
    
   
exception 
  when err_chk then 
     RAISE_APPLICATION_ERROR ( -20003, vErrMsg) ;
  --when others then 
    -- RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/update/15/' ||SQLCODE || SQLERRM) ; 
end;