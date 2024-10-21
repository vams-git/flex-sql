declare 
  wus      u5wusvrr%rowtype;
begin
  select * into wus from u5wusvrr where rowid =:rowid;

  update u5wusvrr 
  set    wus_createdby = o7sess.cur_user,
  wus_created = o7gttime(wus_org)
  where rowid = :rowid;

exception when others then
  RAISE_APPLICATION_ERROR (  -20003,'Error in Flex u5wusvrr/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;