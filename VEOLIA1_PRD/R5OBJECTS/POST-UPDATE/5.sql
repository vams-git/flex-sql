declare
   obj           r5objects%rowtype;
   vCnt          number;
   
   vOrgType              r5organization.org_udfchar10%type;
   vGroup                r5users.usr_group%type;
   vObjChecklistFilter   r5objects.obj_checklistfilter%type;
   vObjProfilePic        r5objects.obj_profilepicture%type;
   vExistObj             varchar2(80);
   
   iErrMsg       varchar2(400);
   err_val       exception;
   
   cursor cur_aat (vObj varchar2, vOrg varchar2)is 
   select aat_column,ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
   from r5audvalues,r5audattribs
   where ava_table = aat_table and ava_attribute = aat_code
   and   aat_table = 'R5OBJECTS' and aat_column in ('OBJ_CHECKLISTFILTER','OBJ_PROFILEPICTURE')
   and   ava_table = 'R5OBJECTS' 
   and   ava_primaryid = vObj and ava_secondaryid = vOrg
   and   ava_updated = '+'
   --and ava_inserted ='+'
   and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
   order by ava_changed desc;
   
begin
    select * into obj from r5objects where rowid=:rowid;
   --clear SAP Asset number when asset is move to TRD status
   if obj.obj_status ='TRD' and obj.obj_udfchar40 is not null then
      update r5objects
      set    obj_udfchar40 = NULL
      where  obj_Code = obj.obj_code and obj_org = obj.obj_org;
   end if;
   
   --validate if obj_udfchar40 is updated 
   if obj.obj_status <> 'TRD' and obj.obj_udfchar40 is not null then
      select count(1) into vCnt
      from r5audvalues ava,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5OBJECTS' and aat_column in ('OBJ_UDFCHAR40')
      and   ava_table = 'R5OBJECTS' 
      and   ava_primaryid = obj.obj_code and ava.ava_secondaryid = obj.obj_org
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
      order by ava_changed desc;
      
      if vCnt > 0 then
         if o7sess.cur_user IN ('MIGRATION','DATABRIDGEINTERNALUSER','ASSET.MANAGEMENT@VEOLIA.COM') then
            iErrMsg := 'SAP Fixed Asset Number is found in VAMS, Interface could not update SAP Asset Number.';
            raise err_val;
         end if;
          --validate SAP Asset number should be unique with in Plant --obj_udfchar38
         begin
            select obj_code||'('||obj_org||')' into vExistObj
            from r5objects 
            where  nvl(obj_udfchar40,'x') = nvl(obj.obj_udfchar40,'x')
            and    nvl(obj_udfchar38,'x') = nvl(obj.obj_udfchar38,'x')
            and    obj_status <> 'TRD'
            --and    obj_code <> obj.obj_Code
            and    rowid<>:rowid
            and    rownum<=1;
            
            iErrMsg := 'SAP Fixed Asset Number is found in VAMS on Asset '|| vExistObj;
            raise err_val;
         exception when no_data_found then  
          null;
         end;
         
         
      end if; --if cnt > 0 then
   end if;


  
    if o7sess.cur_user IN ('MIGRATION','DATABRIDGEINTERNALUSER','ASSET.MANAGEMENT@VEOLIA.COM') then 
       for rec_aat in cur_aat(obj.obj_code,obj.obj_org) loop
          if rec_aat.ava_from is not null and rec_aat.ava_to is null then
            if rec_aat.aat_column = 'OBJ_CHECKLISTFILTER' then
               vObjChecklistFilter := rec_aat.ava_from;
            end if;
            if rec_aat.aat_column = 'OBJ_PROFILEPICTURE' then
               vObjProfilePic := rec_aat.ava_from;
            end if;
         end if;
       end loop;
     
       if vObjChecklistFilter is not null or vObjProfilePic is not null then
          update r5objects set
          obj_checklistfilter = nvl(vObjChecklistFilter,obj_checklistfilter),
          obj_profilepicture  = nvl(vObjProfilePic,obj_profilepicture)
          where obj_Code = obj.obj_code and obj_org = obj.obj_org
          and  
          (
           nvl(obj_checklistfilter,' ') <> nvl(nvl(vObjChecklistFilter,obj_checklistfilter),' ')
           or  nvl(obj_profilepicture,' ') <> nvl(nvl(vObjProfilePic,obj_profilepicture),' ')
          );
         
       end if;
       
    
    end if; --o7sess.cur_user

exception 
  when err_val then 
      RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Update/5/'||SQLCODE || SQLERRM) ; 
end;