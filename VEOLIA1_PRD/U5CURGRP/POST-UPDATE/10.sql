declare 
  cug      u5curgrp%rowtype;
  vDesc    r5costcodes.cst_desc%type;
begin
  select * into cug from u5curgrp where rowid=:rowid;
  select cst_desc into vDesc from r5costcodes where cst_code = cug.cug_costcode;
  if vDesc <> nvl(cug.cug_costcodedesc,' ') then
      update u5curgrp set cug_costcodedesc = vDesc where rowid =:rowid;
  end if;
  
  update u5vucosd set ucd_recalccost = '+' where ucd_id = 4 and nvl(ucd_recalccost,'-') <> '+';
  
exception 
when no_data_found then 
  null;
when others then
    RAISE_APPLICATION_ERROR (  -20003,'Error in Flex u5curgrp/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;