declare 
  ese      r5entityattributesets%rowtype;
begin
  select * into ese from r5entityattributesets where rowid=:rowid;
  if ese.ese_rentity ='PART' and ese.ese_entitycode ='#CAUS' then
     delete from r5entityattributesets where rowid=:rowid;
  end if;
  if ese.ese_rentity ='ASMR' then
     delete from r5entityattributesets where rowid=:rowid;
  end if;
exception when others then
  null;  
end;