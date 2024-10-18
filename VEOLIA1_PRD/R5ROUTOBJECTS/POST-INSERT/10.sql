declare 
   rob r5routobjects%rowtype;
   v_Count number;
   iLang r5users.usr_lang%type;
   iErrMsg  varchar2(200);
   DB_ERROR exception;
begin
   select * into rob from r5routobjects where rowid =:rowid;
   
   select count(1) into v_Count 
   from r5routobjects
   where rob_route = rob.rob_route and rob_revision = rob.rob_revision
   and   rob_object = rob.rob_object and rob_object_org =rob.rob_object_org and rowid<>:rowid;

   if v_Count > 0 then
     begin
     select usr_lang into iLang from r5users where usr_code = o7sess.cur_user;
     exception when no_data_found then
       iLang := 'EN';
     end;
     raise DB_ERROR;
   end if;

exception 
  WHEN DB_ERROR THEN
     if iLang ='EN' then iErrMsg := 'The equipment cannot be added becasue it is already added.';
     elsif iLang = 'ZH' then iErrMsg := '所选设备已加入列表';
     elsif iLang = 'KO' then iErrMsg := '이미 해당설비가 추가되어, 중복추가할 수 없습니다.';
     elsif iLang = 'JP' then iErrMsg := '所选设备已加入列表';
     end if;
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
  when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;