declare
  
begin
   update U5OUFMEA ouf
   set    ouf_createdby = createdby,
          ouf_created = created
   where  ouf.rowid =:rowid;
   
end;