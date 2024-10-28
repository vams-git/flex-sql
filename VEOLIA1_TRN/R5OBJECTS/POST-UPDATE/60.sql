declare
   obj           r5objects%rowtype;
   vCnt          number;
   
   vOrgType      r5organization.org_udfchar10%type;
   vGroup        r5users.usr_group%type;
   vMailTemp     r5mailevents.mae_template%type;
   
   iErrMsg       varchar2(400);
   err_val       exception;
   
begin
    select * into obj from r5objects where rowid=:rowid;
    if obj.obj_udfchkbox04 = '+' then
       select count(1) into vCnt
       from r5audvalues ava,r5audattribs
       where ava_table = aat_table and ava_attribute = aat_code
       and   aat_table = 'R5OBJECTS' and aat_column = 'OBJ_UDFCHKBOX04'
       and   ava_table = 'R5OBJECTS' 
       and   ava_primaryid = obj.obj_code and ava.ava_secondaryid = obj.obj_org
       and   ava_updated = '+' 
       and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
       order by ava_changed desc;
       
       if vCnt > 0 then
         vMailTemp := 'M-FLE-EXCLUDEDVR';
         select count(1) into vCnt from r5mailevents where 
         mae_template = vMailTemp
         and mae_param2 = obj.obj_code
         and abs(sysdate - mae_date) * 24 * 60 * 60 <= 2;
         
         if vCnt = 0 then
         insert into r5mailevents
         (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,MAE_ATTRIBPK,
         MAE_PARAM1,
         MAE_PARAM2,
         MAE_PARAM3,
         MAE_PARAM4,
         MAE_PARAM5,
         MAE_PARAM6,
         MAE_PARAM7,
         MAE_PARAM8,
         MAE_PARAM9,
         MAE_PARAM10
         ) 
        values
        (S5MAILEVENT.NEXTVAL,vMailTemp,sysdate,'-','N',0,
         obj.obj_location,
         obj.obj_code,
         obj.obj_desc,
         obj.obj_udfchar02,
         obj.obj_udfchar04,
         obj.obj_udfchar08,
         obj.obj_udfchar16,
         r5o7.o7get_desc('EN','UCOD',obj.obj_status,'OBST', null) ,
         r5o7.o7get_desc('EN','UCOD',obj.obj_operationalstatus,'EOST', null) ,
         o7sess.cur_user);
       end if;--VCNT = 0 
    end if;--VCNT > 0
  end if;
    

exception 
  when err_val then
     RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Insert/60') ; 
end;