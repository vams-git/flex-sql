declare
   obj           r5objects%rowtype;
   vRegnCode     r5objects.obj_code%type;
   vRegnDesc     r5objects.obj_desc%type;
  
   iErrMsg       varchar2(400);
   err           exception;
   
   
begin
    select * into obj from r5objects where rowid=:rowid;
    if obj.obj_obrtype not in ('A','P') then
       return;
    end if;
    
    begin
      select org_udfchar03 into vRegnCode
      from r5organization
      where org_code = obj.obj_org;
      
      if vRegnCode is null then
         iErrMsg := 'Region is not defined in Organziation, please check.';
         raise err;
      end if;
      
      select obj_desc into vRegnDesc
      from r5objects 
      where obj_obrtype = 'S' and obj_obtype = 'REGN'
      and   obj_org = vRegnCode;
      
      /*iErrMsg := vRegnDesc;
      raise err;*/

      update r5objects 
      set obj_udfchar46 = vRegnCode,
      obj_udfchar47 = vRegnDesc
      where rowid = :rowid
      and (nvl(obj_udfchar46,' ') <> nvl(vRegnCode,' ')
      or   nvl(obj_udfchar47,' ') <> nvl(vRegnDesc,' ')
      );
    exception when no_data_found then
      null;
    end;
    
exception 
  when err then 
      RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Insert/1/'||SQLCODE || SQLERRM) ; 
end;