declare 
  usr r5users%rowtype;

begin
  select * into usr from r5users where rowid=:rowid;
  if NVL(usr.usr_udfchar10,'!!') != '!!' then
     update r5users set usr_udfchar10 = null,
     usr_datelocked = null where rowid=:rowid;
  end if;

exception when others then 
  null;
end;