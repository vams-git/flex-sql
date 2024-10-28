declare 
  oud             r5objusagedefs%rowtype; 
  vObjLastRead    r5objects.obj_udfdate03%type;

begin
  select * into oud from r5objusagedefs where rowid=:rowid;
  select obj_udfdate03 into vObjLastRead from r5objects 
  where obj_code = oud.oud_object and obj_org = oud.oud_object_org;
  if vObjLastRead is null or vObjLastRead < oud.oud_lastreaddate then
     update r5objects
     set obj_udfdate03 = oud.oud_lastreaddate 
     where obj_code = oud.oud_object and obj_org = oud.oud_object_org;
  end if;
  

EXCEPTION
   when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5objusagedefs/Post Update/20/'||substr(SQLERRM, 1, 500)) ; 
end;