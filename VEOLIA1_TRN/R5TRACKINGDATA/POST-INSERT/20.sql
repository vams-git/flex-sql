declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  vNewStatus    r5invoices.inv_status%type;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  
  iErrMsg       varchar2(400);
  err_val       exception;
  
  cursor cur_inv (vSAPInv in varchar2) is 
  select *
  from r5invoices
  where inv_sourcesystem ='SAP'
  and inv_sourcecode = vSAPInv;
begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'INVC' then
    begin
     select count(1) into vCnt from r5invoices
     where inv_sourcesystem ='SAP'
     and inv_sourcecode = tkd.tkd_promptdata1;
     if vCnt = 0 then
         iErrMsg := 'SAP Invoice ' || tkd.tkd_promptdata1 ||' is not found.';
         raise err_val;
     end if;
     
     for inv in cur_inv(tkd.tkd_promptdata1) loop
         if inv.inv_status in ('A') then
            iErrMsg := 'Invoice '||inv.inv_code||'('||inv.inv_org||') is Paid or Approved. Cannot change to Cancelled';
            raise err_val;
         end if;
         vNewStatus := 'C';
         o7preinv(
         'UPD',inv.inv_class,inv.inv_class_org,inv.inv_status,inv.inv_parent,inv.inv_org,inv.inv_supplier,inv.inv_supplier_org,
         inv.inv_total,'MIGRATION',inv.inv_rtype,inv.inv_type,inv.inv_rstatus,vNewStatus,inv.inv_code,inv.inv_org,inv.inv_approv,
         inv.inv_match,inv.inv_record,inv.inv_date,inv.inv_paydate,chk,inv.inv_sourcesystem,inv.inv_sourcecode);
         if chk <> '0' then
             iErrMsg := o7intgem( 'O7PREINV', 'PROC', chk );
             --cmsg := REPLACE( cmsg, ':PARM1', cerrparm1 );
             --cmsg := REPLACE( cmsg, ':PARM2', cerrparm2 );
             raise err_val;
         else
           update r5invoices 
           set inv_status ='C',inv_rstatus ='C',
           inv_udfchar22 = tkd.tkd_promptdata3
           where  inv_code     = inv.inv_code
           and    inv_org      = inv.inv_org;
           
           update r5invoicelines
           set    ivl_matched     = 'N'
           where  ivl_invoice     = inv.inv_code
           and    ivl_invoice_org = inv.inv_org;
         end if;
     end loop;
     
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
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/20/' ||SQLCODE || SQLERRM) ;
end;
