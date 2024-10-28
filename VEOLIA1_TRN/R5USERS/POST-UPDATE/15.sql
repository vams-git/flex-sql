declare 
  usr          r5users%rowtype;

begin
  select * into usr from r5users where rowid=:rowid;
  if usr.usr_udfchkbox02 = '+' then
     update r5users set usr_udfchkbox02 = '-' where rowid=:rowid;
     delete from r5sessions where ses_user = usr.usr_code;
  end if;

exception when others then 
  null;
end;