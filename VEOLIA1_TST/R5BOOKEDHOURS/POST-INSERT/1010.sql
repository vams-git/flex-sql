select rowid from r5bookedhours b 
where b.rowid=:rowid 
and b.boo_udfchar05 is not null 
and exists (select 1 from r5personnel where per_code = b.boo_udfchar05 and per_mrc not like '%-CLIENT')