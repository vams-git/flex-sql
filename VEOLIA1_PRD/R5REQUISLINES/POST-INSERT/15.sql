declare 
   rql              r5requislines%rowtype;
begin
  select * into rql from r5requislines where rowid=:rowid;
  update r5requislines
  set    rql_udfchar29 = null, rql_udfchar30 = null
  where  rowid =:rowid;
  
end;