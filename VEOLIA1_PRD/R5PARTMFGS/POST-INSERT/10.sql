declare 
  mfp               r5partmfgs%rowtype;
  par               r5parts%rowtype;
  
  vMfpDesc          r5manufacturers.mfg_desc%type;
  vManufactpart     r5partmfgs.mfp_manufactpart%type;
  vNewDesc          varchar2(2000);
  vOldDesc          varchar2(2000);
  
  vMsg              varchar2(400);
  err               exception;
begin
  select * into mfp from r5partmfgs where rowid=:rowid;
  if o7sess.cur_user IN ('MIGRATION','DATABRIDGEINTERNALUSER','ASSET.MANAGEMENT@VEOLIA.COM') then
     return;
  end if;

  if mfp.mfp_primary = '+' then
      vMfpDesc := r5o7.o7get_desc('EN', 'MANU', mfp.mfp_manufacturer, '','');
      vManufactpart := mfp.mfp_manufactpart;
      update r5parts
      set par_udfchar29= vMfpDesc
      where par_code = mfp.mfp_part
      and   par_org  = mfp.mfp_part_org
      and   nvl(par_udfchar29,' ') <> nvl(vMfpDesc,' ');
   else
      vMfpDesc := null;
      vManufactpart := null;
      update r5parts
      set par_udfchar29=null
      where par_code = mfp.mfp_part
      and   par_org  = mfp.mfp_part_org
      and   par_udfchar29 is not null;
   end if;
    
   /*
   if mfp.mfp_primary = '+' then
      vMsg := mfp.mfp_part;
         raise err;
      if par.par_tracktype ='TRPQ' and nvl(par.par_udfchkbox05,'-') ='-' then
        
         select substr(
         par.par_udfchar24||','||r5o7.o7get_desc('EN','UOM',par.par_uom,'','') ||
         decode(vManufactpart,null,null,','||vManufactpart)||
         decode(par.par_udfchar27,null,null,','||par.par_udfchar27)||
         decode(par.par_udfchar26,null,null,','||par.par_udfchar26)||
         decode(par.par_udfchar25,null,null,','||par.par_udfchar25)||
         decode(par.par_udfchar30,null,null,','||par.par_udfchar30)
         ,255),par_desc into vNewDesc,vOldDesc
         from r5parts par
         where par.par_code = mfp.mfp_part  
         and   par.par_org  = mfp.mfp_part_org;
         vMsg := vNewDesc;
         raise err;
        if vOldDesc <> nvl(vNewDesc, ' ') then
            update r5parts set par_desc = vNewDesc 
            where par_code = mfp.mfp_part and par_org = mfp.mfp_part_org;
         end if;
      end if;
    end if;
    */
    

exception 
when err then
RAISE_APPLICATION_ERROR (-20001,vMsg) ;  
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5partmfgs/Post Insert/10/'||SQLCODE || SQLERRM) ;

end;