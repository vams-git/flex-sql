declare
    ppo r5ppmobjects%rowtype; 
begin
    select * into ppo from r5ppmobjects where rowid=:rowid;
    if ppo.ppo_mrc is not null then
       update r5ppms
       set    ppm_udfchar29 = ppo.ppo_mrc
       where  ppm_code = ppo.ppo_ppm
       and    ppm_revision =ppo.ppo_revision
       and    ppm_org =ppo.ppo_org
       and    nvl(ppm_udfchar29,' ') <> ppo.ppo_mrc;
    end if; 
exception when others then
 RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;        
end;