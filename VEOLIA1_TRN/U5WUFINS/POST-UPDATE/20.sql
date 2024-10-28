declare 
  fin      u5wufins%rowtype;
begin
  select * into fin from u5wufins where rowid =:rowid;
  if fin.fin_refreshorg = '+' then
     delete from r5descriptions d 
     where d.des_entity = '$UFS' 
     and d.des_rentity =  '$UFS' 
     and d.des_type = '*'
     and d.des_code = fin.fin_code;
     
     insert into r5descriptions (des_entity,des_rentity,des_type,des_rtype,des_code,des_lang,des_text,des_trans,des_org) 
     select '$UFS','$UFS','*','*',fin.fin_code,'EN',fin.description,'+',fin_org
     from u5wuforg where fin_code = fin.fin_code;
     
     update u5wufins set fin_refreshorg = '-' where fin_code = fin.fin_code;
  end if;


exception when others then
  RAISE_APPLICATION_ERROR (  -20003,'Error in Flex u5wufins/Post Update/20/'||substr(SQLERRM, 1, 500)) ; 
end;