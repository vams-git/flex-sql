declare 
  tra                    r5transactions%rowtype;
  
  iErrMsg                varchar2(500);
  err_test               exception;
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_type ='STTK' then
     update r5transactions
     set tra_udfchar01 = o7sess.cur_user
     where rowid =:rowid;
  end if;

exception 
when err_test then 
RAISE_APPLICATION_ERROR (-20001,iErrMsg) ;
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Insert/310') ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;