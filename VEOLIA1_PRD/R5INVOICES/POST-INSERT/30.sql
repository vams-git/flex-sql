declare 
 inv              r5invoices%rowtype;
 vDiscountTaxAmount number;
 vTaxBaseAmount     number;
 vTaxAmount         number;
 vEAMTaxCode        r5taxes.tax_code%type;
 vPurOrg            r5organization.org_udfchar06%type;
 
 iErrMsg            varchar2(400);
 err_msg            exception;
 vCnt               number;
 vTaxDetailLvlCnt   number;
 

 cursor cur_tax (vSAPTaxAll in varchar2,vSpilt in varchar2) is
 select regexp_substr(vSAPTaxAll,'[^'||vSpilt||']+', 1, level) as seg_tax,level as seg_tax_level from dual
 connect by regexp_substr(vSAPTaxAll, '[^'||vSpilt||']+', 1, level) is not null
 order by level;
 
 cursor cur_taxDetails (vSAPTax in varchar2,vSpilt in varchar2) is
 select regexp_substr(vSAPTax,'[^'||vSpilt||']+', 1, level) as seg_taxdetails,level as seg_taxdetails_level  from dual
 connect by regexp_substr(vSAPTax, '[^'||vSpilt||']+', 1, level) is not null
 order by level;

begin
  select * into inv from r5invoices where rowid=:rowid;--inv_code = '100011' and inv_org = 'BAR';--
  if inv.inv_status = 'U' and inv.inv_sourcesystem = 'SAP' then
     --eam udfchar19 TaxCode1:TAX_AMOUNT:TAX_BASE_AMOUNT
     --Get any invoice for same SAP Invoice
     select count(1) into vCnt from r5invoices where inv_sourcesystem =  inv.inv_sourcesystem  and inv_sourcecode = inv.inv_sourcecode;
     if vCnt = 0 then
       
    
     
     if nvl(inv.inv_udfnum04,0) <> 0 then
        vDiscountTaxAmount := 0;
        
        
        --get tax amount and tax base amount 
        if nvl(inv.inv_udfchar21,' ') <> ' ' and  nvl(inv.inv_udfchar19,' ') <> ' ' then
            -- get eam tax code
            select org_udfchar06 into vPurOrg from r5organization where org_code = inv.inv_org;  
            vEAMTaxCode := vPurOrg ||'-'||inv.inv_udfchar21;
            select count(1) into vCnt from r5taxes t where t.tax_code = vEAMTaxCode;
            if vCnt = 0 then
               iErrMsg := 'SAP Unplanned Delivery Cost Tax is not found. Please check with Admin.';
               raise err_msg;
            end if;          
            
            for rec_tax in cur_tax(inv.inv_udfchar19,'#') loop
                if instr(rec_tax.seg_tax,inv.inv_udfchar21) > 0 then
                    --validate sap tax information is completed? should have 3 level
                    select count(1) into vTaxDetailLvlCnt
                    from (
                     select regexp_substr(rec_tax.seg_tax,'[^'||':'||']+', 1, level) as seg_taxdetails  from dual
                     connect by regexp_substr(rec_tax.seg_tax, '[^'||':'||']+', 1, level) is not null
                    );
                    if vTaxDetailLvlCnt < 3 then 
                       iErrMsg := 'Missing SAP Tax Information. Please check with Admin.';
                       raise err_msg;
                    end if;
                    
                    --loop for sap invoice tax information to get amount and calculae extra charge
                   for rec_taxdetails in cur_taxDetails(rec_tax.seg_tax,':') loop
                       if rec_taxdetails.seg_taxdetails_level = 2 then
                          vTaxAmount := to_number(rec_taxdetails.seg_taxdetails);
                       end if;
                       if rec_taxdetails.seg_taxdetails_level = 3 then
                          vTaxBaseAmount := to_number(rec_taxdetails.seg_taxdetails);
                       end if; 
                   end loop;
                   
                end if;
            end loop;
            
        end if;
        
        
        if vTaxAmount >0 and vTaxBaseAmount > 0 then
           vDiscountTaxAmount := round(inv.inv_udfnum04/vTaxBaseAmount*vTaxAmount,3);
        end if;
        
        insert into R5INVDISTRIBUTIONS
        (IVD_INVOICE,
        IVD_LINE,
        IVD_CCID,
        IVD_ORG,
        IVD_AMOUNT,
        IVD_TYPE,
        IVD_RTYPE,
        IVD_TAX,
        IVD_TAXAMOUNT)
        VALUES
        (inv.inv_code,
         0,
         0,
         inv.inv_org,
         inv.inv_udfnum04,
         'PRT',
         'PRT',
         vEAMTaxCode,
         vDiscountTaxAmount
        );
        
     end if;
     
      end if; --CNT = 0

  end if;
exception 
  when err_msg then
     RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5invoices/Insert/30' ||SQLCODE || SQLERRM) ;
end;
 