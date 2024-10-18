declare 
 req              r5requisitions%rowtype;
 vSupplierDesc    r5companies.com_desc%type;
 vReqAddress      r5address.adr_text%type;
 vDelAddress      r5deladdresses.dad_address%type;
 
begin
  select * into req from r5requisitions where rowid=:rowid;
  --Populate Supplier Desc
  vSupplierDesc := r5o7.o7get_desc('EN','COMP',req.req_fromcode,'', '');
  if nvl(vSupplierDesc,' ') <> nvl(req.req_udfchar28,' ') then
     update r5requisitions
     set req_udfchar28 = r5o7.o7get_desc('EN','COMP',req.req_fromcode,'', '') --Supplier Desc
     where rowid =:rowid;
  end if;
  
  --Update Delivery Address
  if req.req_deladdress is not null then
      begin
        select adr_text into vReqAddress from r5address
        where adr_rentity ='REQ' and adr_code = req.req_code and adr_rtype ='D';
      exception when no_data_found then
        vReqAddress := null;
      end;
      
      begin
        select dad_address into vDelAddress from r5deladdresses
        where dad_code = req.req_deladdress;
      exception when no_data_found then
        vDelAddress := null;
      end;
      if nvl(vDelAddress,' ') <> nvl(vReqAddress,' ') then
         delete from r5address where adr_rentity ='REQ' and adr_code = req.req_code and adr_rtype ='D';
         insert into r5address
        (adr_rentity,adr_code,adr_rtype,adr_text,
        adr_address1,adr_address2,adr_address3,adr_city,adr_state,adr_zip,adr_country,
        adr_phone,adr_phoneextn,adr_fax,adr_email)
        select 'REQ',req.req_code,'D',dad_address,
        dad_address1,dad_address2,dad_address3,dad_city,dad_state,dad_zip,dad_country,
        dad_phone,dad_phoneextn,dad_fax,dad_email
        from r5deladdresses
        where dad_code = req.req_deladdress;
      end if;
  end if;
  
exception 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Update/20') ;
end;
 