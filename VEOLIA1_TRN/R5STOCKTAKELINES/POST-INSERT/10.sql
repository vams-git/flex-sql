declare
 stl            r5stocktakelines%rowtype;
 vManufacturer  r5partmfgs.mfp_manufacturer%type;
 vManufactpart  r5partmfgs.mfp_manufactpart%type;
begin
 select * into stl from r5stocktakelines where rowid=:rowid;
 begin
   select mfp_manufacturer,mfp_manufactpart
   into  vManufacturer,vManufactpart
   from  r5partmfgs
   where mfp_part = stl.stl_part and mfp_part_org = stl.stl_part_org
   and   mfp_primary = '+'
   and   rownum<=1;
   
   update r5stocktakelines
   set stl_manufacturer = vManufacturer,
       stl_manufactpart = vManufactpart
   where rowid =:rowid;
 exception when no_data_found then
   null;
 end;
 
exception 
 when others then
   RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5stocktakelines/Post Insert/10');
end;