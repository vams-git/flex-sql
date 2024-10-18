declare 
  inv              r5invoices%rowtype;
  vInvoicedQty     r5invoicelines.ivl_invqty%type;
  vInvoicedValue   r5invoicelines.ivl_invvalue%type;
  
  cursor cur_ivl(iInvOrg varchar2,iInvCode varchar2) is 
  select distinct ivl_order_org,ivl_order,ivl_ordline
  from r5invoicelines 
  where ivl_invoice_org = iInvOrg and ivl_invoice = iInvCode;
  
  cursor cur_invord(iInvOrg varchar2,iInvCode varchar2) is
  select distinct ivl_order_org,ivl_order
  from r5invoicelines 
  where ivl_invoice_org = iInvOrg and ivl_invoice = iInvCode; 
begin
  select * into inv from r5invoices where rowid=:rowid;
  for rec_ivl in cur_ivl(inv.inv_org,inv.inv_code) loop      
      begin
        select nvl(sum(ivl_invqty)-sum(ivl_returnqty),0),nvl(sum(ivl_invvalue)-sum(ivl_returnvalue),0)
        into vInvoicedQty,vInvoicedValue
        from (select 
        case when inv_type ='I' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_invqty),0) else 0 end as ivl_invqty,
        case when inv_type ='C' and inv_return ='+' and inv_status ='A' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_returnqty),0) else 0 end as ivl_returnqty,
        case when inv_type in ('I','D') then 
        nvl(ivl_invvalue,0)+nvl(ivl_totextra,0) else 0 end as ivl_invvalue,
        case when inv_type in ('C') then
        nvl(ivl_invvalue,0)+nvl(ivl_totextra,0) else 0 end as ivl_returnvalue  
        from   r5invoices,r5invoicelines
        where  inv_code = ivl_invoice and inv_org =ivl_invoice_org
        --and    inv_type = 'I' 
        and inv_status  not in ('C','U')
        and    ivl_order = rec_ivl.ivl_order and ivl_ordline =rec_ivl.ivl_ordline
        and    ivl_order_org = rec_ivl.ivl_order_org
        );
      exception when no_data_found then
        vInvoicedQty := 0;
        vInvoicedValue := 0;
      end;
      
      update r5orderlines
      set    ORL_UDFNUM04 = vInvoicedQty
      where  orl_order = rec_ivl.ivl_order and orl_ordline = rec_ivl.ivl_ordline
      and    orl_order_org = rec_ivl.ivl_order_org 
      and    nvl(orl_udfnum04,0)<>vInvoicedQty;
  end loop;
  
  for rec_invord in cur_invord(inv.inv_org,inv.inv_code) loop      
      begin
        select nvl(sum(ivl_invqty)-sum(ivl_returnqty),0),nvl(sum(ivl_invvalue)-sum(ivl_returnvalue),0)
        into vInvoicedQty,vInvoicedValue
        from (select 
        case when inv_type ='I' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_invqty),0) else 0 end as ivl_invqty,
        case when inv_type ='C' and inv_return ='+' and inv_status ='A' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_returnqty),0) else 0 end as ivl_returnqty,
        case when inv_type in ('I','D') then 
        nvl(ivl_invvalue,0)+nvl(ivl_totextra,0) else 0 end as ivl_invvalue,
        case when inv_type in ('C') then
        nvl(ivl_invvalue,0)+nvl(ivl_totextra,0) else 0 end as ivl_returnvalue  
        from   r5invoices,r5invoicelines
        where  inv_code = ivl_invoice and inv_org =ivl_invoice_org
        --and    inv_type = 'I' 
        and inv_status in ('A')
        and    ivl_order = rec_invord.ivl_order 
        and    ivl_order_org = rec_invord.ivl_order_org
        );
      exception when no_data_found then
        vInvoicedQty := 0;
        vInvoicedValue := 0;
      end;
      
      update r5orders
      set    ord_udfnum05 = vInvoicedValue
      where  ord_code = rec_invord.ivl_order 
      and    ord_org = rec_invord.ivl_order_org 
      and    nvl(ord_udfnum05,0)<>vInvoicedValue;
  end loop;

exception
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5INVOICES/Post Update/200'); 
end;