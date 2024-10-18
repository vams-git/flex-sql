declare
  flr            r5fuelreceipts%rowtype;
  vDupCnt        number;
  vDupSum        number;

  vErrMsg        varchar2(400);
  err_val        exception;

begin
  select * into flr from r5fuelreceipts where rowid=:rowid;
  -- Retrieve count of the previous similar entry from the depot record or tank
  select count(1) into vDupCnt from r5fuelreceipts fp
  where fp.flr_depot_org = flr.flr_depot_org and fp.flr_depot = flr.flr_depot
    and fp.flr_tank = flr.flr_tank and fp.flr_fuel = flr.flr_fuel
    and fp.flr_supplier_org = flr.flr_supplier_org
    and fp.flr_supplier = flr.flr_supplier and fp.flr_price = fp.flr_price
    and fp.flr_qty = flr.flr_qty and TRUNC(fp.flr_date) = TRUNC(flr.flr_date)
    and fp.flr_code <> flr.flr_code;
    
  if vDupCnt > 0 then
    -- Check if this is a re-entry of a reverse
    select sum(fp.flr_qty) into vDupSum from r5fuelreceipts fp
    where fp.flr_depot_org = flr.flr_depot_org and fp.flr_depot = flr.flr_depot
      and fp.flr_tank = flr.flr_tank and fp.flr_fuel = flr.flr_fuel
      and fp.flr_supplier_org = flr.flr_supplier_org
      and fp.flr_supplier = flr.flr_supplier and fp.flr_price = fp.flr_price
      and TRUNC(fp.flr_date) = TRUNC(flr.flr_date)
      and fp.flr_code <> flr.flr_code;
      
    -- vDupSum != 0 then new record already exist
    if vDupSum != 0 and (vDupSum + flr.flr_qty) > 0 then
      vErrMsg := 'Record already exist!';
      raise err_val;
    end if;
  end if; 
exception
when err_val then
  RAISE_APPLICATION_ERROR (-20003,
    'E/R5FUELRECEIPTS/20/I - '||vErrMsg);
when others then
  RAISE_APPLICATION_ERROR (-20003,
    'E/R5FUELRECEIPTS/20/I - '||substr(SQLERRM, 1, 500));
end;