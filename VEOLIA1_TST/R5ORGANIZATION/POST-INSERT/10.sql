declare 
  org      r5organization%rowtype;
  vUser    r5users.usr_code%type;
  vGroup   r5users.usr_group%type;
  vCnt     number;
  
begin
  select * into org from r5organization where rowid=:rowid;
  
  select p.pnr_ewsuserid into vUser from R5PARTNERS p where p.pnr_code = 'INFOR-ONRAMP';
  
  vUser := 'MIGRATION';
  select count(1) into vCnt from r5userorganization
  where uog_user =vUser and uog_org = org.org_code;
  
  begin
    select usr_group into vGroup from r5users where usr_code = vUser;
    if vCnt = 0 then
      insert into r5userorganization u
      (uog_user,uog_org,uog_default,uog_common,uog_group,
       uog_reqappvlimit,uog_reqauthappvlimit,uog_pordappvlimit,uog_pordauthappvlimit,uog_picappvlimit,uog_invappvlimit,uog_invappvlimitnonpo,uog_role)
      values
      (vUser,org.org_code,'-',org.org_common,vGroup,
      9999999,9999999,9999999,9999999,9999999,9999999,9999999,'*');
    end if;
  exception when no_data_found then
    null;
  end;
  
  vUser := 'ASSET.MANAGEMENT@VEOLIA.COM';
  select count(1) into vCnt from r5userorganization
  where uog_user =vUser and uog_org = org.org_code;
  
  begin
    select usr_group into vGroup from r5users where usr_code = vUser;
    if vCnt = 0 then
      insert into r5userorganization u
      (uog_user,uog_org,uog_default,uog_common,uog_group,
       uog_reqappvlimit,uog_reqauthappvlimit,uog_pordappvlimit,uog_pordauthappvlimit,uog_picappvlimit,uog_invappvlimit,uog_invappvlimitnonpo,uog_role)
      values
      (vUser,org.org_code,'-',org.org_common,vGroup,
      9999999,9999999,9999999,9999999,9999999,9999999,9999999,'*');
    end if;
  exception when no_data_found then
    null;
  end;
  
  vUser := 'R5';
  select count(1) into vCnt from r5userorganization
  where uog_user =vUser and uog_org = org.org_code;
  
  begin
    select usr_group into vGroup from r5users where usr_code = vUser;
    if vCnt = 0 then
      insert into r5userorganization u
      (uog_user,uog_org,uog_default,uog_common,uog_group,
       uog_reqappvlimit,uog_reqauthappvlimit,uog_pordappvlimit,uog_pordauthappvlimit,uog_picappvlimit,uog_invappvlimit,uog_invappvlimitnonpo,uog_role)
      values
      (vUser,org.org_code,'-',org.org_common,vGroup,
      9999999,9999999,9999999,9999999,9999999,9999999,9999999,'*');
    end if;
  exception when no_data_found then
    null;
  end;
  
exception when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5organization/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;