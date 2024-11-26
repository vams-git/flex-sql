declare 
  com      r5companies%rowtype;
  vPart    r5parts.par_code%type;
  vPartOrg r5parts.par_org%type;

begin
  select * into com from r5companies where rowid=:rowid;
  
  select par_code,par_org into vPart,vPartOrg from r5parts where par_code = '000000001020000191';
  begin
	insert into r5catalogue
	(cat_part,cat_part_org,cat_supplier,cat_supplier_org,cat_curr,cat_date)
	values
	(vPart,vPartOrg,com.com_code,com.com_org,com.com_curr,trunc(o7gttime(com.com_org)));
  end;
  
  select par_code,par_org into vPart,vPartOrg from r5parts where par_code = '000000001020000912';
  begin
	insert into r5catalogue
	(cat_part,cat_part_org,cat_supplier,cat_supplier_org,cat_curr,cat_date)
	values
	(vPart,vPartOrg,com.com_code,com.com_org,com.com_curr,trunc(o7gttime(com.com_org)));
  end;
  
  
exception when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5companies/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;