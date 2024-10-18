declare
   orl              r5orderlines%rowtype;
   vInvoicePaidQty  r5orderlines.orl_udfnum05%type;
   vReceiptQty      r5orderlines.orl_recvvalue%type;
   vOrderQty        r5orderlines.orl_ordqty%type;
   vInvoicecQty     r5orderlines.orl_udfnum04%type;
   vOrlActive       r5orderlines.orl_active%type;
   
   vNewValue        r5audvalues.ava_from%type;
   vOldValue        r5audvalues.ava_from%type;
   vTimeDiff        number;

begin
    select * into orl from r5orderlines where rowid=:rowid;
    select nvl(decode(orl.orl_type,'SF',orl.orl_recvvalue,orl.orl_recvqty),0),
           nvl(decode(orl.orl_type,'SF',orl.orl_price,orl.orl_ordqty),0),
           nvl(orl.orl_udfnum04,0)
    into vReceiptQty,vOrderQty,vInvoicecQty from dual; 

    
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
     if orl.orl_type like 'S%' and orl.orl_status  = 'CP' and nvl(vReceiptQty,0) < nvl(vOrderQty,0) then
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
     end if;  

exception 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/update/15/' ||SQLCODE || SQLERRM) ; 
end;