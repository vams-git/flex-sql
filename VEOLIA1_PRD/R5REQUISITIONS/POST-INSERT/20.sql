declare 
 req              r5requisitions%rowtype;
 vCount           number;
 
begin
  select * into req from r5requisitions where rowid=:rowid;
  --Duplidate Record reset UDF
  --Populate Enter By Name and Supplier Desc
  update r5requisitions
  set    req_udfchar23 = null,--Approved/Rejected By Name
         req_udfchar29 = null,--Purchase Order Number
         req_udfchar25 = (select usr_emailaddress  from r5users where usr_code = req.req_enteredby),
         req_udfchar27 = r5o7.o7get_desc('EN','USER',req.req_enteredby,'', ''),--Enter By Name
         req_udfchar28 = r5o7.o7get_desc('EN','COMP',req.req_fromcode,'', '') --Supplier Desc
  where  rowid =:rowid;
  
  --Insert Delivery Address
  select count(1) into vCount from r5address
  where adr_rentity ='REQ' and adr_code = req.req_code and adr_rtype ='D';
  if vCount > 0 then
     delete from r5address where adr_rentity ='REQ' and adr_code = req.req_code and adr_rtype ='D';
  end if;
  if req.req_deladdress is not null then
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
  

/*exception 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Insert/20') ;*/
end;
 