declare 
  inv              r5invoices%rowtype;
  vInvoicedQty     r5invoicelines.ivl_invqty%type;
  vReturnQty       r5invoicelines.ivl_returnqty%type;
  vInvoicedValue   r5invoicelines.ivl_invvalue%type;
  vReturnValue       r5invoicelines.ivl_invvalue%type;
  
  iErrMsg          varchar2(500);
  errValidate      exception;
  vCount           number;
  
  cursor cur_ivl(iInvOrg varchar2,iInvCode varchar2) is 
  select distinct ivl_type,ivl_order_org,ivl_order,ivl_ordline,ivl_udfchar25,ivl_udfchar24
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
        case when inv_type ='C' and inv_return ='+'then 
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
        and    ivl_udfchar25 = rec_ivl.ivl_udfchar25 and nvl(ivl_udfchar24,' ')= rec_ivl.ivl_udfchar24
        );
      exception when no_data_found then
        vInvoicedQty := 0;
        vInvoicedValue := 0;
      end;

      if rec_ivl.ivl_type like 'S%' then
         update r5bookedhours
         set boo_udfnum04 = vInvoicedQty,
             boo_udfnum05 = vInvoicedValue
         where boo_code = rec_ivl.ivl_udfchar25
         and  (nvl(boo_udfnum04,0)<>vInvoicedQty
            or nvl(boo_udfnum05,0)<>vInvoicedValue);
      else
         update r5translines
         set trl_udfnum04 = vInvoicedQty,
             trl_udfnum05 = vInvoicedValue
         where trl_trans = rec_ivl.ivl_udfchar25
         and   trl_line = rec_ivl.ivl_udfchar24
         and   (nvl(trl_udfnum04,0)<>vInvoicedQty
            or  nvl(trl_udfnum05,0)<>vInvoicedValue);
      end if;
      
      
  end loop;

/*exception
when errValidate then
RAISE_APPLICATION_ERROR (-20001,iErrMsg);   
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5INVOICES/Post Update/210'); */
end;