declare 
  tra                    r5transactions%rowtype;
  vLocale                varchar2(80);
  vGroup                 r5users.usr_group%type;
  iErrMsg                varchar2(500);
  err_test               exception;
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_type ='STTK' and tra.tra_status = 'A' then
     select nvl(usr_udfchar30,' '),usr_group 
     into   vLocale,vGroup
     from r5users where usr_code = o7sess.cur_user;
     
     if  vLocale = 'NZ' and vGroup not in ('VWA-FINANCE') then
         iErrMsg := 'You are not authorized to approve a physical inventory';
         raise err_test;
     end if;
  end if;

exception 
when err_test then 
RAISE_APPLICATION_ERROR (-20001,iErrMsg) ;
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Update/320') ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;