declare 
 inv              r5invoices%rowtype;
 vUserDesc        r5users.usr_desc%type;
 
begin
  select * into inv from r5invoices where rowid=:rowid;
  if inv.inv_status ='C' and inv.inv_udfchar22 is not null then
      begin
         select r5o7.o7get_desc('EN','USER',usr_code,'', '') into vUserDesc from r5users where usr_emailaddress = inv.inv_udfchar22 and rownum<=1;
      exception when no_data_found then
         vUserDesc := null;
      end;
       update r5invoices
       set inv_udfchar24 = vUserDesc
       where rowid =:rowid
       and nvl(inv_udfchar24,' ') <> nvl(vUserDesc,' ');
  end if;

exception 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5invoices/update/20') ;
end;
 