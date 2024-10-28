declare 
  fin      u5wufins%rowtype;
begin
  select * into fin from u5wufins where rowid =:rowid;

  delete from r5descriptions d 
  where d.des_entity = '$UFS' 
  and d.des_rentity = '$UFS' 
  and d.des_type ='*'
  and d.des_code = fin.fin_code and d.des_org = '*';

exception when others then
  RAISE_APPLICATION_ERROR (  -20003,'Error in Flex u5wufins/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;