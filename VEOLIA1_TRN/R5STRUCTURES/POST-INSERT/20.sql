declare
   stc           r5structures%rowtype;
   curr_obj      r5objects%rowtype;
   vUDFChar01 varchar2(80);
   vUDFChar02 varchar2(80);
   vUDFChar03 varchar2(80);
   vUDFChar04 varchar2(80);
   vUDFChar05 varchar2(80);
   vUDFChar06 varchar2(80);
   vUDFChar07 varchar2(80);
   vUDFChar08 varchar2(80);
   vUDFChar09 varchar2(80);
   vUDFChar10 varchar2(80);
   vUDFChar11 varchar2(80);
   vUDFChar12 varchar2(80);
   
   cursor cur_parent(vChild varchar2,vOrg varchar2) is
   select obj.*
   from r5objects obj,
   (select *
   from r5structures
   connect by prior stc_parent = stc_child and prior stc_parent_org = stc_child_org
   start with stc_child = vChild and stc_child_org =vOrg)
   where obj_code = stc_parent and obj_org = stc_parent_org
   and   (obj_obrtype in ('A','P') or obj_obtype in ('CRTC'));
   
   cursor cur_child(vChild varchar2,vOrg varchar2) is
   select obj.*
   from r5objects obj,
   (select *
   from r5structures
   connect by prior stc_child = stc_parent and prior stc_child_org = stc_parent_org
   start with stc_parent = vChild and stc_parent_org = vOrg)
   where obj_code = stc_child and obj_org = stc_child_org
   and   obj_obrtype in ('A','P');

begin
    select * into stc from r5structures 
    --where stc_child ='1EDE-00116561' and stc_parent = '10125';
    where rowid=:rowid;
    if (stc.stc_ParentType ='CRTC' or stc.stc_ParentrType = 'P'
      or stc.stc_childrType = 'P' or stc.stc_ParentrType = 'A' ) then
      
        vUDFChar01 := null;
        vUDFChar02 := null;
        vUDFChar03 := null;
        vUDFChar04 := null;
        vUDFChar05 := null;
        vUDFChar06 := null;
        vUDFChar07 := null;
        vUDFChar08 := null;
        vUDFChar09 := null;
        vUDFChar10 := null;
        vUDFChar11 := null;
        vUDFChar12 := null;
        
        --get current obj udf
        select * into curr_obj from r5objects where obj_Code = stc.stc_child and obj_org = stc.stc_child_org;
        if curr_obj.obj_obtype = 'CRTC' then
           vUDFChar01 := curr_obj.obj_variable1;
           vUDFChar02 := curr_obj.obj_desc;
        elsif curr_obj.obj_obtype = '01ST' then
           vUDFChar03 := curr_obj.obj_code;
           vUDFChar04 := curr_obj.obj_desc;
        elsif curr_obj.obj_obtype = '02ET' then
           vUDFChar05 := curr_obj.obj_code;
           vUDFChar06 := curr_obj.obj_desc;
        elsif curr_obj.obj_obtype = '03UT' then
           vUDFChar07 := curr_obj.obj_code;
           vUDFChar08 := curr_obj.obj_desc;
        elsif curr_obj.obj_obtype = '04AS' then
           vUDFChar09 := curr_obj.obj_code;
           vUDFChar10 := curr_obj.obj_desc;
        elsif curr_obj.obj_obtype = '05FP' then
           vUDFChar11 := curr_obj.obj_code;
           vUDFChar12 := curr_obj.obj_desc;
        end if;
        
        --get parent for current object
        for rec_parent in cur_parent(stc.stc_child,stc.stc_child_org) loop
            if rec_parent.obj_obtype = 'CRTC' then
               vUDFChar01 := rec_parent.obj_variable1;
               vUDFChar02 := rec_parent.obj_desc;
            elsif rec_parent.obj_obtype = '01ST' then
               vUDFChar03 := rec_parent.obj_code;
               vUDFChar04 := rec_parent.obj_desc;
            elsif rec_parent.obj_obtype = '02ET' then
               vUDFChar05 := rec_parent.obj_code;
               vUDFChar06 := rec_parent.obj_desc;
            elsif rec_parent.obj_obtype = '03UT' then
               vUDFChar07 := rec_parent.obj_code;
               vUDFChar08 := rec_parent.obj_desc;
            elsif rec_parent.obj_obtype = '04AS' then
               vUDFChar09 := rec_parent.obj_code;
               vUDFChar10 := rec_parent.obj_desc;
            elsif rec_parent.obj_obtype = '05FP' then
               vUDFChar11 := rec_parent.obj_code;
               vUDFChar12 := rec_parent.obj_desc;
            end if;
        end loop;
        
        --update current object udf
        
        update r5objects
        set obj_udfchar01 = nvl(vUDFChar01,obj_udfchar01),
        obj_udfchar02 = nvl(vUDFChar02,obj_udfchar02),
        obj_udfchar03 = nvl(vUDFChar03,obj_udfchar03),
        obj_udfchar04 = nvl(vUDFChar04,obj_udfchar04),
        obj_udfchar05 = nvl(vUDFChar05,obj_udfchar05),
        obj_udfchar06 = nvl(vUDFChar06,obj_udfchar06),
        obj_udfchar07 = nvl(vUDFChar07,obj_udfchar07),
        obj_udfchar08 = nvl(vUDFChar08,obj_udfchar08),
        obj_udfchar09 = nvl(vUDFChar09,obj_udfchar09),
        obj_udfchar10 = nvl(vUDFChar10,obj_udfchar10),
        obj_udfchar11 = nvl(vUDFChar11,obj_udfchar11),
        obj_udfchar12 = nvl(vUDFChar12,obj_udfchar12)
        where obj_code = stc.stc_child
        and   obj_org  = stc.stc_child_org
        and (
        nvl(obj_udfchar01,' ') <> nvl(vUDFChar01,' ') or
        nvl(obj_udfchar02,' ') <> nvl(vUDFChar02,' ') or
        nvl(obj_udfchar03,' ') <> nvl(vUDFChar03,' ') or
        nvl(obj_udfchar04,' ') <> nvl(vUDFChar04,' ') or
        nvl(obj_udfchar05,' ') <> nvl(vUDFChar05,' ') or
        nvl(obj_udfchar06,' ') <> nvl(vUDFChar06,' ') or
        nvl(obj_udfchar07,' ') <> nvl(vUDFChar07,' ') or
        nvl(obj_udfchar08,' ') <> nvl(vUDFChar08,' ') or
        nvl(obj_udfchar09,' ') <> nvl(vUDFChar09,' ') or
        nvl(obj_udfchar10,' ') <> nvl(vUDFChar10,' ') or
        nvl(obj_udfchar11,' ') <> nvl(vUDFChar11,' ') or
        nvl(obj_udfchar12,' ') <> nvl(vUDFChar12,' ')
        );
       
        --get all children for current obj
        for rec_child in cur_child(stc.stc_child,stc.stc_child_org) loop
            update r5objects
            set obj_udfchar01 = nvl(vUDFChar01,obj_udfchar01),
            obj_udfchar02 = nvl(vUDFChar02,obj_udfchar02),
            obj_udfchar03 = nvl(vUDFChar03,obj_udfchar03),
            obj_udfchar04 = nvl(vUDFChar04,obj_udfchar04),
            obj_udfchar05 = nvl(vUDFChar05,obj_udfchar05),
            obj_udfchar06 = nvl(vUDFChar06,obj_udfchar06),
            obj_udfchar07 = nvl(vUDFChar07,obj_udfchar07),
            obj_udfchar08 = nvl(vUDFChar08,obj_udfchar08),
            obj_udfchar09 = nvl(vUDFChar09,obj_udfchar09),
            obj_udfchar10 = nvl(vUDFChar10,obj_udfchar10),
            obj_udfchar11 = nvl(vUDFChar11,obj_udfchar11),
            obj_udfchar12 = nvl(vUDFChar12,obj_udfchar12)
            where obj_code = rec_child.obj_code
            and   obj_org  = rec_child.obj_org
            and (
            nvl(obj_udfchar01,' ') <> nvl(vUDFChar01,' ') or
            nvl(obj_udfchar02,' ') <> nvl(vUDFChar02,' ') or
            nvl(obj_udfchar03,' ') <> nvl(vUDFChar03,' ') or
            nvl(obj_udfchar04,' ') <> nvl(vUDFChar04,' ') or
            nvl(obj_udfchar05,' ') <> nvl(vUDFChar05,' ') or
            nvl(obj_udfchar06,' ') <> nvl(vUDFChar06,' ') or
            nvl(obj_udfchar07,' ') <> nvl(vUDFChar07,' ') or
            nvl(obj_udfchar08,' ') <> nvl(vUDFChar08,' ') or
            nvl(obj_udfchar09,' ') <> nvl(vUDFChar09,' ') or
            nvl(obj_udfchar10,' ') <> nvl(vUDFChar10,' ') or
            nvl(obj_udfchar11,' ') <> nvl(vUDFChar11,' ') or
            nvl(obj_udfchar12,' ') <> nvl(vUDFChar12,' ')
            );
        end loop;
    end if;
   
exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5structures/insert/20/' ||SQLCODE || SQLERRM) ; 
end;
