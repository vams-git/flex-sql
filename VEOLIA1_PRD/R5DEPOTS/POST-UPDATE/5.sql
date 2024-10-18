declare 
 dep        r5depots%rowtype;
 
 vErrMsg    varchar2(400);
 err_val    exception;

begin
 select * into dep from r5depots where rowid=:rowid;
 if dep.dep_class in ('GIF','CRD') and nvl(dep.dep_external,'-') = '-' then
    update r5depots
    set dep_external = '+'
    where rowid = :rowid
    and dep_class in ('GIF','CRD') and nvl(dep_external,'-') = '-';
 end if;
 
 
exception
when err_val then
   RAISE_APPLICATION_ERROR (-20003,vErrMsg) ;   
when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5depots/Post Update/5/'||substr(SQLERRM, 1, 500)) ;   
end;