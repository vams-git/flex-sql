declare
   orl              r5orderlines%rowtype;
   vManufactPart    r5partmfgs.mfp_manufactpart%type;
   vManufact        r5manufacturers.mfg_code%type;
   vManufactDesc    r5manufacturers.mfg_desc%type;

begin
    select * into orl from r5orderlines where rowid=:rowid;
    if orl.orl_type like 'S%' then
       update r5orderlines set orl_udfchar27 = orl_udfchar20
       where rowid=:rowid
       and nvl(orl_udfchar27,' ') <> nvl(orl_udfchar20,' ');
    end if;
    if orl.orl_part is not null then
     begin
        select mfp_manufactpart ,mfp_manufacturer,r5o7.o7get_desc('EN','MANU',mfp_manufacturer,'','')
        into vManufactPart,vManufact,vManufactDesc
        from r5partmfgs
        where mfp_part = orl.orl_part
        and mfp_part_org = orl.orl_part_org and mfp_primary = '+';
      exception when no_data_found then
        vManufactPart := null;
        vManufact     := null;
        vManufactDesc := null;
      end;
    end if;
    
    if vManufactPart is not null and vManufact is not null then
       update r5orderlines
       set orl_MANUFACTURER = vManufact,
       orl_MANUFACTPART = vManufactPart
       where rowid =:rowid
       and (nvl(orl_MANUFACTURER,' ') <> nvl(vManufact,' ')
       or nvl(orl_MANUFACTPART,' ') <> nvl(vManufactPart,' '));
    end if;
    
    
    
   
exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/insert/10/' ||SQLCODE || SQLERRM) ; 
end;