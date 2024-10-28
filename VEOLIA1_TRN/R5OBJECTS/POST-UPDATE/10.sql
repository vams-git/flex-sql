declare
   obj           r5objects%rowtype;
   vUDFNum02     r5objects.obj_udfnum02%type;
   vDepend       r5objects.obj_depend%type;
   vLocDesc      r5objects.obj_desc%type;
   
   cursor cur_chi(vObj varchar2,vOrg varchar2,vXLoc number,vYloc number) is
   select obj_code,obj_org
   from r5objects 
   where obj_position = vObj and obj_position_org = vOrg
   and   (nvl(obj_xcoordinate,0) <> nvl(vXLoc,0) or nvl(obj_ycoordinate,0) <> nvl(vYloc,0));
      
   
begin
    select * into obj from r5objects where rowid=:rowid;
    
    begin
      vUDFNum02 := null;
      if nvl(obj.obj_criticality,'*') <> '*' and nvl(obj.obj_udfchar21,'*') <> '*' then
         vUDFNum02 := to_number(obj.obj_criticality) * to_number(obj.obj_udfchar21);                 
      end if;
    exception when others then 
      vUDFNum02 := null;
    end;
    if nvl(obj.obj_udfnum02,-99) <> nvl(vUDFNum02,-99) then
       update r5objects 
       set obj_udfnum02 = vUDFNum02
       where rowid = :rowid;
    end if;
     
    if obj.obj_obtype in ('02ET','03UT','04AS','05FP','06EQ','07CP') then
        vDepend := '-';
        if obj.obj_obtype in ('02ET', '03UT', '04AS', '05FP','07CP' ) and obj.obj_parent is not null then
           vDepend := '+';
        end if;
        if obj.obj_obtype in ('06EQ') and obj.obj_position is not null then
           vDepend := '+';
        end if;
        if nvl(obj.obj_depend,'-') <> nvl(vDepend,'-') then 
           update r5objects 
           set obj_depend = vDepend
           where rowid = :rowid;
        end if;
    end if;
    
    if obj.obj_obtype in ('05FP') and obj.obj_xcoordinate is not null then
       for rec_chi in cur_chi(obj.obj_code,obj.obj_org,obj.obj_xcoordinate,obj.obj_ycoordinate) loop
           update r5objects 
           set    obj_xcoordinate = obj.obj_xcoordinate,
                  obj_ycoordinate = obj.obj_ycoordinate
           where obj_code = rec_chi.obj_code and obj_org = rec_chi.obj_org
           and   (nvl(obj_xcoordinate,0) <> nvl(obj.obj_xcoordinate,0) or nvl(obj_ycoordinate,0) <> nvl(obj.obj_ycoordinate,0));
       end loop;
    end if;
    /*
    if obj.obj_obtype = 'CRTC' then
      if (nvl(obj.obj_udfchar01,' ') <> nvl(obj.obj_variable1,' ')
       or nvl(obj.obj_udfchar02,' ') <> nvl(obj.obj_desc,' ')
       ) then
           update r5objects 
           set obj_udfchar01 = obj.obj_variable1,
           obj_udfchar02 = obj.obj_desc
           where rowid = :rowid
           and  (nvl(obj_udfchar01,' ') <> nvl(obj.obj_variable1,' ')
           or nvl(obj_udfchar02,' ') <> nvl(obj.obj_desc,' ')
           );
       end if;
    end if;
    if obj.obj_obtype = '01ST' then
      if (nvl(obj.obj_udfchar03,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar04,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar03 = obj.obj_code,
         obj_udfchar04 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar03,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar04,' ') <> nvl(obj.obj_desc,' ')
         );
      end if;
    end if;
    if obj.obj_obtype = '02ET' then
      if (nvl(obj.obj_udfchar05,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar06,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar05 = obj.obj_code,
         obj_udfchar06 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar05,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar06,' ') <> nvl(obj.obj_desc,' ')
         );
      end if;
    end if;
    if obj.obj_obtype = '03UT' then
      if (nvl(obj.obj_udfchar07,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar08,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar07 = obj.obj_code,
         obj_udfchar08 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar07,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar08,' ') <> nvl(obj.obj_desc,' ')
         );
       end if;
    end if;
    if obj.obj_obtype = '04AS' then
      if (nvl(obj.obj_udfchar09,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar10,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar09 = obj.obj_code,
         obj_udfchar10 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar09,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar10,' ') <> nvl(obj.obj_desc,' ')
         );
      end if;
    end if;
    if obj.obj_obtype = '05FP' then
      if (nvl(obj.obj_udfchar11,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar12,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar11 = obj.obj_code,
         obj_udfchar12 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar11,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar12,' ') <> nvl(obj.obj_desc,' ')
         );
       end if;
    end if;
    if obj.Obj_Obrtype = 'A' then
      if (nvl(obj.obj_udfchar13,' ') <> nvl(obj.obj_code,' ')
       or nvl(obj.obj_udfchar14,' ') <> nvl(obj.obj_desc,' ')
       ) then
         update r5objects 
         set obj_udfchar13 = obj.obj_code,
         obj_udfchar14 = obj.obj_desc
         where rowid = :rowid
         and  (nvl(obj_udfchar13,' ') <> nvl(obj.obj_code,' ')
         or nvl(obj_udfchar14,' ') <> nvl(obj.obj_desc,' ')
         );
       end if;
    end if;*/

exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Update/10') ; 
end;