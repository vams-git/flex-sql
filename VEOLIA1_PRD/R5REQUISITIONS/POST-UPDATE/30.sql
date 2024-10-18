declare 
 req              r5requisitions%rowtype;
 
 vParUOM          r5requislines.rql_uom%type;
 vSAPUOM          r5requislines.rql_uom%type;
 vPurUom          r5requislines.rql_uom%type;
 vPurQty          r5requislines.rql_qty%type;
 vPurPrice        r5requislines.rql_price%type;
 vMultiply        r5requislines.Rql_Multiply%type;
 
 iErrMsg          varchar2(400);
 val_err          exception;

 CURSOR curs_rql(vReqCode varchar2) IS
 SELECT * FROM r5requislines
 WHERE rql_req = vReqCode
 and  rql_status not in ('C');
 
begin
  select * into req from r5requisitions where rowid=:rowid;
    
  if req.req_status in ('01SS','04RS') then
      if instr(req.req_desc,'Generate Requisitions Default Desc. To Be Updated' )> 0 then
         iErrMsg := 'Please update requistion Description before submitting';
         raise val_err;
      end if;
        
      for rec_rql in curs_rql(req.req_code) loop
         begin
           select par_uom into vParUOM
           from r5parts where par_code = nvl(rec_rql.rql_part,rec_rql.rql_udfchar27)
           and par_org = 'CAUS' and par_notused ='-';
         exception when no_data_found then
           iErrMsg := nvl(rec_rql.rql_part,rec_rql.rql_udfchar27) || ' is not active or not found for CAUS in VAMS.';
           raise val_err;
         end;
         vPurUom := nvl(rec_rql.rql_uom,vParUOM);
         vMultiply := 1;
         if rec_rql.rql_type like 'S%' then
            select decode(rec_rql.rql_type,'SF',rec_rql.rql_price,rec_rql.rql_qty),decode(rec_rql.rql_type,'SF',rec_rql.rql_qty,rec_rql.rql_price)
            into vPurQty,vPurPrice
            from dual;
            vPurUom := vParUOM;
         else
           begin
                select cat_puruom,cat_multiply
                into vPurUom,vMultiply
                from r5catalogue
                where cat_part = rec_rql.rql_part and cat_part_org = rec_rql.rql_part_org
                and   cat_supplier = rec_rql.rql_supplier and cat_supplier_org = rec_rql.rql_supplier_org
                and   rownum <= 1;
            exception when no_data_found then
                null;
            end;
            if  vPurUom is null then
                vPurUom := nvl(rec_rql.rql_uom,vParUOM);
            end if;
            if vMultiply is null or vMultiply <1 then
               vMultiply:=1;
            end if;
            vPurQty := rec_rql.rql_qty/vMultiply;
            vPurPrice := rec_rql.rql_price*vMultiply;
         end if;
         
         begin
           select Sum_Sapinternalcode into vSAPUOM
           from u5sapuom,r5uoms
           where sum_uom = uom_code and uom_notused ='-'
           and sum_uom =  vPurUom
           and Sum_Sapinternalcode is not null
           and rownum <= 1;
         exception when no_data_found then
           vSAPUOM := vPurUom;
         end;
         
          update r5requislines 
          set rql_udfchar01 = vPurUom,
          rql_udfchar02 = vSAPUom,
          rql_udfnum01 = vPurQty,
          rql_udfnum02 = vPurPrice,
          rql_udfnum03 = vMultiply
          where rql_req = rec_rql.rql_req and rql_reqline = rec_rql.rql_reqline
          and (
          nvl(rql_udfchar01,' ') <> nvl(vPurUom,' ')
          or nvl(rql_udfchar02,' ') <> nvl(vSAPUom,' ')
          or nvl(rql_udfnum01,0) <> nvl(vPurQty,0)
          or nvl(rql_udfnum02,0) <> nvl(vPurPrice,0)
          or nvl(rql_udfnum03,0) <> nvl(vMultiply,0)
          );            
      end loop;
  end if;
  

  
exception 
  when val_err then 
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Update/30/'||SQLCODE || SQLERRM) ;
end;
 