declare 
  org      r5organization%rowtype;
  
  cursor cur_ava(vOrgCode in Varchar) is
  select ava_to, ava_from, timediff
  from 
  (select ava_to, ava_from,
  abs(sysdate - ava_changed) * 24 * 60 * 60 AS timediff
  from R5AUDVALUES, R5AUDATTRIBS
  where ava_table = aat_table AND ava_attribute = aat_code
  and   aat_table = 'R5ORGANIZATION' AND aat_column = 'ORG_UDFCHKBOX03'
  and   ava_table = 'R5ORGANIZATION' AND ava_primaryid = vOrgCode
  order by ava_changed desc)
  where rownum <=1;
begin
  select * into org from r5organization where rowid=:rowid;
  for rec_ava in cur_ava(org.org_code) loop
      if nvl(rec_ava.ava_to,'-') = '-' and nvl(rec_ava.ava_from,'-') = '+' then
         --reset datalake tiem
          UPDATE DATALAKE_TABLE
          SET LASTUPDATEDAT = TO_DATE('19000101','RRRRMMDD')
          WHERE SCHEDULEID IN ('13','15');
      end if;
  end loop;
exception 
  when others then 
     RAISE_APPLICATION_ERROR (-20003,'ERR/r5organization/20/I/'||SUBSTR(SQLERRM, 1, 500));
end;