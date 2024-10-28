declare
 rql               r5requislines%rowtype;
 vUOM              r5parts.par_uom%type;
 vParUdfchar01     r5parts.par_udfchar01%type;
 vOrg              r5requisitions.req_org%type;
 vStore            r5requisitions.req_tocode%type;
 vConCode          r5contracts.con_code%type;
 vConDesc          r5contracts.con_desc%type;
 vMultiply         r5conparts.cpa_multiply%type;
 vCpaPrice         r5conparts.cpa_price%type;
 
 
 err_val          exception;
 iErrMsg          varchar2(500);
 
begin
  select * into rql from r5requislines where rowid=:rowid;
  select req_org,req_tocode into vOrg,vStore from r5requisitions where req_code = rql.rql_req;
  if rql.rql_type = 'ST' and rql.rql_status = 'U' then
     select par_uom into vUOM
     from r5parts where par_code = rql.rql_udfchar27 and par_org = 'CAUS';
     if vUOM not in ('h.') then
        iErrMsg := 'Please note only Service Type with h. UOM can be used for this type.';
        raise err_val;
     end if;
  end if; 
  
  if rql.rql_type like 'S%' and rql.rql_status = 'U' then
     select par_udfchar01,par_uom into vParUdfchar01,vUOM
     from   r5parts where par_code = rql.rql_udfchar27 and par_org = 'CAUS';
     if vParUdfchar01 in ('ZSER') and vUOM in ('h.') and rql.rql_price = 1 then 
        iErrMsg := 'Please note Price ex. GST (UOM) cannot be for material type with a unit of measure in hour. Please modify the unit price accordingly';
        raise err_val;
     end if;
  end if;

  if rql.rql_type = 'SF' and rql.rql_status = 'U' then
     if rql.rql_qty <> 1 then 
        iErrMsg := 'Please note Service Qty Requested must be 1 for Lump Sum with WO.';
        raise err_val;
     end if;
  end if;
  
  if rql.rql_status = 'U' then
    begin
         select con_code,con_desc,cpa_multiply,cpa_price
         into vConCode,vConDesc,vMultiply,vCpaPrice 
         from r5contracts,r5conparts 
         where con_org = vOrg
         and con_code = cpa_contract
         and con_store = vStore
         and con_supplier = rql.rql_supplier and con_supplier_org = rql.rql_supplier_org
         and cpa_part = rql.rql_part and cpa_part_org = rql.rql_part_org
         and trunc(o7gttime(vOrg)) >= con_start
         and trunc(o7gttime(vOrg)) <= con_end
         and con_status ='A'
         and rownum <= 1;
         if vCpaPrice is not null and vMultiply is not null then
             if round(rql.rql_price,6) <> round(vCpaPrice/vMultiply,6) then
                 update r5requislines
                 set    rql_price = round(vCpaPrice/vMultiply,6),
                 rql_udfnum02 = nvl(rql_udfnum03,1) *  round(vCpaPrice/vMultiply,6)
                 where  rowid =:rowid;
                 --iErrMsg := 'Part is defined is Purchase Contract ' || vConCode ||'-'||vConDesc || ' , the price could not be changed';
                 --raise err_val;
             end if;
         end if;
    exception when no_data_found then
        null;
    end;
  end if;

exception 
  when no_data_found then
    null;
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
    RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requislines/Update/210/'||SQLCODE || SQLERRM) ;
end;