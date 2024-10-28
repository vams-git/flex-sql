declare 
 ock   r5operatorchecklists%rowtype;
begin
  select * into ock from r5operatorchecklists where rowid=:rowid; 
  update r5operatorchecklists
  set    ock_udfdate01 = trunc(ock.ock_startdate)
  where  ock_udfdate01 is null and rowid=:rowid;
exception when others then
 RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;