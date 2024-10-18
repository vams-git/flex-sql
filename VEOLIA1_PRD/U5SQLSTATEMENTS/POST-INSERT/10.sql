declare 
stmt clob;
--pragma autonomous_transaction;
begin
for i in (
	select t.*,t.rowid as nRowid 
	from u5sqlstatements t
	where sst_sql is not null 
        and sst_active = '+'
	and rowid = :rowid
)
loop
	stmt := i.sst_sql;
	execute immediate stmt;
	update u5sqlstatements set sst_active = '-'
	where rowid = i.nRowid;
end loop;
end;