declare 
  clcd         r5failures%rowtype;
  vMetaCode    varchar2(80);
  vMetaEntity  varchar2(30);
  vCnt         number;
begin
  select * into clcd from r5failures where rowid=:rowid;
  vMetaCode := 'FAIL'||'#'||clcd.fal_code||'#*';
  vMetaEntity := 'CLCD';
  select count(1) into vCnt from u5vucomd where cmd_code = vMetaCode and cmd_sourceentity =vMetaEntity;
  if vCnt = 0 then
    insert into u5vucomd
    (cmd_code,cmd_sourceentity,
     cmd_clc_code,cmd_clc_type,cmd_clc_typedesc,cmd_clc_notused,description,
     createdby,created,updatecount)
    values
    (vMetaCode,vMetaEntity,
     clcd.fal_code,'FAIL','Failure code',clcd.fal_notused,clcd.fal_desc,
     o7sess.cur_user,sysdate,0);
  else
    update u5vucomd
    set description =  clcd.fal_desc,
    cmd_clc_notused =  clcd.fal_notused
    where cmd_code = vMetaCode and cmd_sourceentity = vMetaEntity;
  end if;
end;