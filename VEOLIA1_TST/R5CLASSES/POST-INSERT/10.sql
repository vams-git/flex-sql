declare 
  cls          r5classes%rowtype;
  vMetaCode    varchar2(80);
  vMetaEntity  varchar2(30);
  vCnt         number;
begin
  select * into cls from r5classes where rowid=:rowid;
  vMetaCode := cls.cls_entity||'#'||cls.cls_code||'#'||cls.cls_org;
  vMetaEntity := 'CLAS';
  select count(1) into vCnt from u5vucomd where cmd_code = vMetaCode and cmd_sourceentity =vMetaEntity;
  if vCnt = 0 then
    insert into u5vucomd
    (cmd_code,cmd_sourceentity,
    cmd_cls_entity,cmd_cls_entitydesc,cmd_cls_code,description,cmd_cls_notused,
    createdby,created,updatecount)
    values
    (vMetaCode,vMetaEntity,
    cls.cls_entity,r5o7.o7get_desc('EN','UCOD',cls.cls_entity,'ENTP', ''),cls.cls_code,cls.cls_desc,cls.cls_notused,
    o7sess.cur_user,sysdate,0);
  else
    update u5vucomd
    set description =  cls.cls_desc,
    cmd_cls_notused = cls.cls_notused
    where cmd_code = vMetaCode and cmd_sourceentity = vMetaEntity;
  end if;

end;