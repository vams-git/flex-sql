declare 
  uog      r5userorganization%rowtype;

  
begin
  select * into uog from r5userorganization where rowid=:rowid;
  begin
    insert into r5departmentsecurity
    (dse_user,dse_mrc,dse_updatecount,dse_readonly)
    select distinct usr_code,mrc_code,0,'-'
    from r5users,r5mrcs
    where usr_code <> '*' 
   --and mrc_code <> '*'
    and   upper(usr_desc) not like '%DEACTIVATE%'
    and   nvl(mrc_notused,'-') <> '+'
    and   (usr_code||'#'||mrc_code) not in (select dse_user||'#'||dse_mrc from r5departmentsecurity)
    and   usr_code = uog.uog_user and mrc_org = uog.uog_org;
  end;


exception when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5userorganization/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;