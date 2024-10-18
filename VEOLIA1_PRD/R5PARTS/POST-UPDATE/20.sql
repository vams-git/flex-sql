declare 
  par             r5parts%rowtype;
  vManufactpart   r5partmfgs.mfp_manufactpart%type;
  vNewDesc        varchar2(500);  
  vTracktype      r5parts.par_tracktype%type;
  vService        r5parts.par_udfchkbox05%type;
  
  iErrMsg         varchar2(500);  
  err_validate    exception;
begin
  select * into par from r5parts where rowid=:rowid;
   /**1. Validate Part Organization **/
   if par.par_org not in ('CAUS') then 
      iErrMsg := 'Wrong Org is selected. Please select CAUS.';
      raise err_validate;
   end if;
   
   if par.par_udfchar24 is null then
      iErrMsg := 'Primary Desription is mandatory.';
      raise err_validate;
   end if;

    /**3. Update Part Tracking method/service by SAP Material Type*
    ZSPA  Spare Parts
    ZSER  Service
    ZGAM  Goods */  
    if par.par_udfchar01 = 'ZSPA' then
      vTracktype := 'TRPQ';
      vService := '-';
    elsif par.par_udfchar01 = 'ZSER' then
      vTracktype := 'TRQ';
      vService := '+';
    elsif par.par_udfchar01 = 'ZGAM' then
      vTracktype := 'TRQ';
      vService := '-';
    end if;
    
    if par.par_class in ('FUEL','ADBLUE') then
        vTracktype := 'TRQ';
    end if;
    
    update r5parts 
    set --par_desc = vNewDesc,
        par_tracktype = vTracktype,
        par_trackrtype = vTracktype,
        par_udfchkbox05 = vService
    where par_code = par.par_code and par_org = par.par_org
    and   (par_tracktype <> vTracktype or par_udfchkbox05 <> vService); 
    
    if nvl(par.par_sourcecode,' ') <> nvl(par.par_udfchar20,' ') then
       update r5parts
       set    par_sourcecode = par.par_udfchar20
       where  par_code = par.par_code and par_org = par.par_org
       and    nvl(par.par_sourcecode,' ') <> nvl(par.par_udfchar20,' ');
    end if;

exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5PARTS/Post Update/200');
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;   
end;