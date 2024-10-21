declare 
 ord              r5orders%rowtype;
 vCount           number;
 vOrderDate       r5orders.ord_date%type;
 vUDFChar24       r5orders.ord_udfchar24%type;
 vUDFChar25       r5orders.ord_udfchar25%type;
 vEnteredby       r5orders.ord_udfchar28%type;
 iErrMsg          varchar2(400);
 err_val          exception;
 
 vComment         varchar2(4000);
 vLine            number;
 
begin
  select * into ord from r5orders where rowid=:rowid;
  if ord.ord_udfchar29 is not null and ord.ord_sourcesystem in ('SAP') then
    begin
       select req_date,req_udfchar24,req_udfchar25,req_enteredby
       into vOrderDate,vUDFChar24,vUDFChar25,vEnteredby
       from r5requisitions
       where req_code = ord.ord_udfchar29
       and req_org = ord.ord_org;
    exception when no_data_found then
       iErrMsg := 'Requistion is not found in VAMS!';
       raise err_val;
    end;
    
    update r5requisitions
    set req_udfchar29 = ord.ord_code,
    req_udfchar23 = ord.ord_udfchar23
    where req_code = ord.ord_udfchar29
    and req_org = ord.ord_org;
    
    --Insert comment
    begin
       select 
       dbms_lob.substr(TO_CLOB(
           R5REP.TRIMHTML(add_code,add_entity,add_type,add_lang,add_line) 
           ),3500,1)
       into vComment
       from r5addetails
       where add_entity ='PORD' 
       and add_code= ord.ord_code||'#'||ord.ord_org
       and add_lang ='EN'
       and rownum <=1;
     exception when no_data_found then
       vComment := null;
     end;
     
     if vComment is not null then
       vLine:=0;
       begin
        select add_line into vLine
        from r5addetails
        where add_entity ='REQ' and add_code = ord.ord_udfchar29
        and add_lang ='EN';
       exception when no_data_found then
          vLine:=0;
       end;
       vLine:=vLine+10;
       insert into r5addetails
       (add_entity,add_rentity,add_type,add_rtype,add_code,
       add_lang,add_line,add_print,add_text,add_created,add_user)
       values
       ('REQ','REQ','*','*',ord.ord_udfchar29,
       'EN',vLine,'+',vComment,o7gttime(ord.ord_org),O7SESS.cur_user);
     end if;
     
     --insert docuemnt 
     insert into r5docentities
     (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,
      dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
     select dae_document,'PORD','PORD',dae_type,dae_rtype,ord.ord_code||'#'||ord.ord_org,
     dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo
     from r5docentities
     where dae_entity = 'REQ'
     and   dae_code = ord.ord_udfchar29
     and   dae_document not in 
     (select dae_document from r5docentities where dae_entity = 'PROD' and dae_code = ord.ord_code||'#'||ord.ord_org);
     
  end if;
  
  
  --Populate Orginator Name and Supplier desc
  update r5orders
  set    ord_udfchar26 = r5o7.o7get_desc('EN','PERS',ord.ord_origin,'', ''),--Originator Name
         ord_udfchar27 = r5o7.o7get_desc('EN','COMP',ord.ord_supplier,'', ''),--Supplier Desc.
         ord_udfnum04 = 0,
         ord_udfchar24 = vUDFChar24,
         ord_udfchar25 = vUDFChar25,
         ord_udfchar28 = vEnteredby--,
         --ord_date = nvl(vOrderDate,ord_date)
  where  rowid =:rowid;
  
  --Insert Delivery Address
  select count(1) into vCount from r5address
  where adr_rentity ='PORD' and adr_code = ord.ord_code||'#'||ord.ord_org and adr_rtype ='D';
  if vCount > 0 then
     delete from r5address where adr_rentity ='PORD' and adr_code = ord.ord_code||'#'||ord.ord_org and adr_rtype ='D';
  end if;
  if ord.ord_deladdress is not null then
    insert into r5address
    (adr_rentity,adr_code,adr_rtype,adr_text,
    adr_address1,adr_address2,adr_address3,adr_city,adr_state,adr_zip,adr_country,
    adr_phone,adr_phoneextn,adr_fax,adr_email)
    select 'PORD',ord.ord_code||'#'||ord.ord_org,'D',dad_address,
    dad_address1,dad_address2,dad_address3,dad_city,dad_state,dad_zip,dad_country,
    dad_phone,dad_phoneextn,dad_fax,dad_email
    from r5deladdresses
    where dad_code = ord.ord_deladdress;
 end if;
 
  

exception 
   when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
   when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orders/insert/30/' ||SQLCODE || SQLERRM) ;
end;
 