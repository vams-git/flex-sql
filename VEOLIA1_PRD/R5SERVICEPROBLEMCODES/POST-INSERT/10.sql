DECLARE
spb           r5serviceproblemcodes%rowtype;
v_contract    varchar2(15);
v_Count       number;

CURSOR curs_mrc(vContract varchar2) IS
SELECT mrc_code FROM r5mrcs
WHERE mrc_org = vContract;

begin
   select * into spb from r5serviceproblemcodes where rowid=:rowid; 

  select code into v_contract  from (
    select regexp_substr(spb.spb_code,'[^-]+', 1, level) as code,level from dual
    where level = 1
    connect by regexp_substr(spb.spb_code,'[^-]+', 1, level) is not null
   );
   
   
     
   for rec_mrc in curs_mrc(v_contract) loop
    select count(1) into v_count
    from r5departmentstructure
    where DPS_MRC=rec_mrc.mrc_code
    and DPS_SERVICEPROBLEM IS null
    and DPS_SERVICEPROBLEM_ORG IS null;
    if v_count=0 then
     insert into r5departmentstructure
     (DPS_CODE,DPS_MRC,DPS_SERVICEPROBLEM,DPS_SERVICEPROBLEM_ORG)
     values
     (S5DEPARTMENTSTRUCTURE.NEXTVAL,rec_mrc.mrc_code,NULL,NULL);
    end if;  
   
     select count(1) into v_count
     from r5departmentstructure
     where DPS_MRC=rec_mrc.mrc_code
     and DPS_SERVICEPROBLEM=spb.spb_code
     and DPS_SERVICEPROBLEM_ORG=spb.spb_org;
     if v_count=0 then
       insert into r5departmentstructure
       (DPS_CODE,DPS_MRC,DPS_SERVICEPROBLEM,DPS_SERVICEPROBLEM_ORG)
       values
       (S5DEPARTMENTSTRUCTURE.NEXTVAL,rec_mrc.mrc_code,spb.spb_code,spb.spb_org);
     end if;
   end loop;

exception when others then
  RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;