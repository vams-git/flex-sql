declare 
  mrc   r5mrcs%rowtype;
  
begin
  select * into mrc from r5mrcs where rowid=:rowid;
  begin
    insert into r5departmentsecurity
    (dse_user,dse_mrc,dse_updatecount,dse_readonly)
    select distinct usr_code,mrc_code,0,'-'
    from r5users,r5mrcs
    where usr_code <> '*' 
    and   mrc_code = mrc.mrc_code
    and   upper(usr_desc) not like '%DEACTIVATE%'
    and   nvl(mrc_notused,'-') <> '+'
    and   (usr_code||'#'||mrc_code) not in (select dse_user||'#'||dse_mrc from r5departmentsecurity);
  end;


exception when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5mrcs/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;