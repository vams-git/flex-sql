declare
   orl                     r5orderlines%rowtype;
   vNewOrdStatus           r5orderlines.orl_status%type;
   vCurrStatus             r5orderlines.orl_status%type;
   vLineCnt                 number;
   vInvoiceLineCnt          number;
   vInactiveLineCnt         number;
   iTotalRecvQty            r5orderlines.orl_recvqty%type;
   
   vOrdRecvValue            r5orderlines.orl_recvvalue%type;
   vTotalRecvValue          r5orderlines.orl_recvvalue%type;
   vReqStatusCnt            number;
   vOrdStatusCnt            number;

begin
    select * into orl from r5orderlines where rowid=:rowid;
    
    select ord_status,ord_udfnum04 into vCurrStatus,vOrdRecvValue
    from r5orders
    where ord_org = orl.orl_order_org
    and   ord_code = orl.orl_order;
    if vCurrStatus in ('U') then
        return;
    end if;
    
    select sum(nvl(orl_recvvalue,0)) into vTotalRecvValue from r5orderlines 
    where orl_order = orl.orl_order and orl_order_org = orl.orl_order_org;
    if nvl(vOrdRecvValue,0) <> nvl(vTotalRecvValue,0) then
       update r5orders 
       set ord_udfnum04 = vTotalRecvValue
       where ord_code = orl.orl_order and ord_org = orl.orl_order_org;
    end if;
    
    
    if orl.orl_active = '-' then
       --get total line of POs
       select count(1) into vLineCnt
       from r5orderlines
       where orl_order =orl.orl_order
       and orl_order_org = orl.orl_order_org; 
       
       --get all invoiced qty
       select count(1) into vInvoiceLineCnt
       from r5orderlines
       where orl_order = orl.orl_order
       and orl_order_org = orl.orl_order_org
       and orl_active = '-'
       and ((orl_type not in ('SF') and nvl(orl_invqty,0) >= nvl(orl_recvqty,0))
            or (orl_type in ('SF') and nvl(orl_invvalue,0) >= nvl(orl_recvvalue,0)));
            
       --get all inactive count
       select count(1) into vInactiveLineCnt
       from r5orderlines
       where orl_order = orl.orl_order
       and orl_order_org = orl.orl_order_org
       and orl_active = '-';
       
       --get total receipt qty
       select sum(nvl(orl_recvqty,0)) into iTotalRecvQty
       from r5orderlines
       WHERE  orl_order = orl.orl_order
       and    orl_order_org = orl.orl_order_org;
       
       if vLineCnt = vInactiveLineCnt then
        if iTotalRecvQty = 0 then
           vNewOrdStatus := 'CAN';
        else
          if vLineCnt = vInvoiceLineCnt then
            vNewOrdStatus := 'RI';
          else
            vNewOrdStatus := 'RC';
          end if;
        end if;
     end if;
     
     if vNewOrdStatus is not null then
        --dbms_output.put_line(vNewStatus);
        select count(1) into vReqStatusCnt
        from r5requisitions
        where req_code = orl.orl_req
        and req_status <> vNewOrdStatus;

        select count(1) into vOrdStatusCnt
        from r5orders
        where  ord_code = orl.orl_order
        and    ord_org = orl.orl_order_org
        and    ord_status <> vNewOrdStatus;

        if vReqStatusCnt > 0 or vOrdStatusCnt > 0 then
          --dbms_output.put_line('UPDATE TO NEW STATUS');
          update r5orders
          set    ord_status = vNewOrdStatus
          where  ord_code = orl.orl_order
          and    ord_org = orl.orl_order_org;
          --and    ord_status <> vNewStatus;

          update r5requisitions
          set req_status = vNewOrdStatus
          where req_code = orl.orl_req
          and  req_status <> vNewOrdStatus;
        end if;
     end if;

    end if;  
    
    if orl.orl_active = '+' then
       --get total receipt qty
       select sum(nvl(decode(orl_type,'SF',orl_recvvalue,orl_recvqty),0)) into iTotalRecvQty
       from r5orderlines
       WHERE  orl_order = orl.orl_order;
       if iTotalRecvQty = 0 then
         vNewOrdStatus := 'A';
       else 
         vNewOrdStatus := 'RP';
       end if;

       
       select count(1) into vReqStatusCnt
       from r5requisitions
       where req_code = orl.orl_req
       and req_status <> nvl(vNewOrdStatus,' ');
       
       select count(1) into vOrdStatusCnt
       from   r5orders
       where  ord_code = orl.orl_order
       and    ord_org = orl.orl_order_org
       and    ord_status <> nvl(vNewOrdStatus,' ');

       if vReqStatusCnt > 0 or vOrdStatusCnt > 0 then
          update r5orders
          set    ord_status = vNewOrdStatus
          where  ord_code = orl.orl_order
          and    ord_org = orl.orl_order_org;
          --and    ord_status <> vNewStatus;

          update r5requisitions
          set req_status = vNewOrdStatus
          where req_code = orl.orl_req
          and  req_status <> vNewOrdStatus;
       end if;
    end if;

/*exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/update/30/' ||SQLCODE || SQLERRM) ; */
end;