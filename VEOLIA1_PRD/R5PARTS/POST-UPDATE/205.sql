declare 
  par               r5parts%rowtype;
  
  vManufactpart     r5partmfgs.mfp_manufactpart%type;
  vNewDesc          nvarchar2(2000);
  vNewLDesc        nvarchar2(4000);
  vMfpDesc          r5manufacturers.mfg_desc%type;
begin
  select * into par from r5parts where rowid=:rowid;
  
  /**2. Update Part Description**/
   --If :new.par_tracktype ='TRPQ' and :new.par_udfchkbox05 = '-' then
  --he Primary Manufacturer Part Number is not included, please can you add it
  --Description + Size + Material + Primary Manufacturer Part Number +Specification
  --DESC + UDFCHAR27  + UDFCHAR26 + R5PARTMFGS.MFP_MANUFACTPART  + UDFCHAR25
  begin
    select mfp_manufactpart, r5o7.o7get_desc('EN','MANU',mfp_manufacturer, '','')
    into vManufactpart,vMfpDesc
    from r5partmfgs
    where mfp_part = par.par_code
    and mfp_part_org = par.par_org and mfp_primary = '+';
  exception when no_data_found then
    vManufactpart := null;
    vMfpDesc := null; 
  end;
  
  if nvl(par.par_udfchar29,' ') <> vMfpDesc then
     update r5parts
     set par_udfchar29= vMfpDesc
     where rowid=:rowid;
  end if;
 
  select
  substr(
  par.par_udfchar24||','||r5o7.o7get_desc('EN','UOM',par.par_uom,'','') ||
  decode(vManufactpart,null,null,','||vManufactpart)||
  decode(par.par_udfchar27,null,null,','||par.par_udfchar27)||
  decode(par.par_udfchar26,null,null,','||par.par_udfchar26)||
  decode(par.par_udfchar25,null,null,','||par.par_udfchar25)||
  decode(par.par_udfchar30,null,null,','||par.par_udfchar30)
  ,1,255)
  into vNewDesc
  from dual;
 
  select
  substr(
  par.par_code || ',' || chr(10) || par.par_udfchar24 || ',' ||
  r5o7.o7get_desc('EN', 'UOM', par.par_uom, '', '') ||
  decode(vManufactpart, null, null, ',' || chr(10) || vManufactpart) ||
  decode(par.par_udfchar30, null, null, ',' || chr(10) || par.par_udfchar30) ||
  decode(par.par_udfchar27, null, null, ',' || chr(10) || par.par_udfchar27) ||
  decode(par.par_udfchar26, null, null, ',' || chr(10) || par.par_udfchar26) ||
  decode(par.par_udfchar25, null, null, ',' || chr(10) || par.par_udfchar25) ||
  decode(par.par_udfchar30, null, null, ',' || chr(10) ||par.par_udfchar30)
  ,1,2000)
  into vNewLDesc
  from dual;
  
  if par.par_desc <> nvl(vNewDesc, ' ')
  or nvl(par.par_longdescription,'x') <> nvl(vNewLDesc, ' ') then
     update r5parts
     set par_desc = vNewDesc,
     par_longdescription = vNewLDesc
     where rowid=:rowid;
     update r5descriptions set des_text = vNewDesc 
     where des_entity ='PART' and des_type ='*' 
     and des_org = par.par_org and des_code = par.par_code;
  end if;

exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5parts/Post Update/205/'||SQLCODE || SQLERRM) ;
end;