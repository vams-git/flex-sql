declare
    ppm           r5ppms%rowtype; 
    
    vNewValue     r5audvalues.ava_to%type;
    vOldValue     r5audvalues.ava_from%type;
    vTimeDiff     number;
    vCount        number;
    
    iErrMsg       varchar2(400);
    err_val       exception;
    
    cursor cur_ppo(vPPmCode varchar2,vPPMRevision number) is
    select * from r5ppmobjects
    where ppo_ppm = vPPmCode and ppo_revision = vPPMRevision;
begin
    select * into ppm from r5ppms where rowid=:rowid;
    
    --Check is Status Update?
    begin
      select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
       from (
      select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5PPMS' and aat_column = 'PPM_ISSTYPE'
      and   ava_table = 'R5PPMS' 
      and   ava_primaryid = ppm.ppm_code
      and   ava_secondaryid = ppm.ppm_revision
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
      order by ava_changed desc
      ) where rownum <= 1;
    exception when no_data_found then 
      vNewValue := null;
      return;
    end;
    
    --work order could change from duplidate to fixed or vairable 
    if vNewValue in  ('F','V') then
        for rec_ppo in cur_ppo(ppm.ppm_code,ppm.ppm_revision) loop
            if nvl(ppm.ppm_isstype,' ') <> nvl(rec_ppo.ppo_isstype,' ') then
              update r5ppmobjects
              set    ppo_isstype = ppm.ppm_isstype
              where  ppo_ppm = ppm.ppm_code and ppo_revision = ppm.ppm_revision;
            end if;
        end loop;
    end if;
    
    if vNewValue in ('D') and vOldValue in  ('F','V') then
       --Any ppm object is still not in 'D' stop change
       select count(1) into vCount
       from   r5ppmobjects
       where  ppo_ppm = ppm.ppm_code and ppo_revision = ppm.ppm_revision
       and    ppo_isstype not in ('D');
       if vCount > 0 then 
          iErrMsg := 'PM Type cannot be changed to Duplicate as assoicated PM type is Fixed or variable';
          raise err_val;
       end if;
    end if;

exception 
when err_val then
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5ppms/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;