declare
    ppm r5ppms%rowtype; 
    iOldWOIDPT  varchar2(80);
begin
    select * into ppm from r5ppms where rowid=:rowid;
    if ppm.ppm_udfchar29 is not null then
       update r5ppmobjects
       set    ppo_mrc = ppm.ppm_udfchar29
       where  ppo_ppm = ppm.ppm_code
       and    ppo_revision =ppm.ppm_revision
       and    ppo_org =ppm.ppm_org
       and    ppo_mrc <> ppm.ppm_udfchar29;

    end if; 
    

exception when others then
 RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;        
end;