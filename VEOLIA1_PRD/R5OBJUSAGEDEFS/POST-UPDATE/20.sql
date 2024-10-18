declare 
  oud             r5objusagedefs%rowtype; 
  vObjLastRead    r5objects.obj_udfdate03%type;
  vOperType       r5organization.org_udfchar10%type;
  
  cursor cur_rea_fleet(vObj in varchar2,vOrg in varchar2) is
  select * from (
    select rea_object,rea_object_org,rea_uom,rea_date,
           row_number() over (partition by rea_object,rea_object_org order by rea_date desc) as rn
    from r5readings
    where rea_object = vObj and rea_object_org = vOrg
    and ((rea_uom in ('h.','h_B','H_A1','h_A2') and rea_diff > 2)
         or (rea_uom in ('KM.') and rea_diff > 10))
    and rea_lastsaved >= sysdate - 365
  ) where rn = 1;
  
  cursor cur_rea_oth(vObj in varchar2,vOrg in varchar2) is
  select * from (
    select rea_object,rea_object_org,rea_uom,rea_date,
           row_number() over (partition by rea_object, rea_object_org order by rea_date desc) AS rn
    from r5readings
    where rea_object = vObj and rea_object_org = vOrg
    and rea_lastsaved >= sysdate - 365
  ) where rn = 1;

begin
  select * into oud from r5objusagedefs where rowid=:rowid;
  
  select org_udfchar10 into vOperType from r5organization where org_code = oud.oud_object_org;
  if vOperType = 'Waste (Fleet)' then
     for rec in cur_rea_fleet(oud.oud_object,oud.oud_object_org) loop
         vObjLastRead := rec.rea_date;
     end loop;
  else
     for rec in cur_rea_oth(oud.oud_object,oud.oud_object_org) loop
         vObjLastRead := rec.rea_date;
     end loop;
  end if;
  
  update r5objects
  set obj_udfdate03 = vObjLastRead 
  where obj_code = oud.oud_object and obj_org = oud.oud_object_org;
  

EXCEPTION
   when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5objusagedefs/Post Update/20/'||substr(SQLERRM, 1, 500)) ; 
end;