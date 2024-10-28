declare 
 inv              r5invoices%rowtype;
 vSupplierDesc    r5companies.com_desc%type;
 vABN             r5companies.com_udfchar30%type;
 vUserDesc        r5users.usr_desc%type;
 
begin
  select * into inv from r5invoices where rowid=:rowid;
  vSupplierDesc := r5o7.o7get_desc('EN','COMP',inv.inv_supplier,'', '');
  begin
     select com_udfchar30 into vABN from r5companies where com_code = inv.inv_supplier and com_org = inv.inv_supplier_org;
   exception when no_data_found then
     vABN := null;
   end;
   begin
     select r5o7.o7get_desc('EN','USER',usr_code,'', '') into vUserDesc from r5users where usr_emailaddress = inv.inv_udfchar23 and rownum<=1;
   exception when no_data_found then
     vUserDesc := null;
   end;
   
   update r5invoices
   set inv_udfchar27 = vSupplierDesc,
   inv_udfchar26 = vABN,
   inv_udfchar28 = vUserDesc
   where rowid =:rowid
   and (
   nvl(inv_udfchar27,' ') <> nvl(vSupplierDesc,' ')
   or nvl(inv_udfchar26,' ') <> nvl(vABN,' ')
   or nvl(inv_udfchar28,' ') <> nvl(vUserDesc,' ')
   );

exception 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5invoices/Insert/10') ;
end;
 