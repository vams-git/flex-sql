declare 
  tou      r5toolusage%rowtype;
begin
  select * into tou from r5toolusage where rowid = :rowid;
  if tou.tou_cost <> tou.tou_hours * tou.tou_qty * tou.tou_tariff then
     update r5toolusage 
     set tou_cost = tou.tou_hours * tou.tou_qty * tou.tou_tariff
     where rowid =:rowid;
  end if;
  
end;