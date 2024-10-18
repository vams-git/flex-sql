declare 
 flr            r5fuelreceipts%rowtype;
 vPriceAvg      r5fuelreceipts.flr_price%type;
 vPriceVar      r5tanks.tan_udfnum01%type;
 vPricePrev     r5fuelreceipts.flr_price%type;
 vPriceLower    r5fuelreceipts.flr_price%type;
 vPriceUpper    r5fuelreceipts.flr_price%type;
 
 vErrMsg        varchar2(400);
 err_val        exception;

begin
 select * into flr from r5fuelreceipts where rowid=:rowid;
 
 --validate receipt price with tank % of deviation of unit price (udfnum01)
 -- Retrieve the tank avg price and % of deviation from the tank
 select nvl(tan_avgprice,0),tan_udfnum01 into vPriceAvg,vPriceVar
 from r5tanks
 where tan_depot = flr.flr_depot and tan_depot_org = flr.flr_depot_org
 and   tan_code = flr.flr_tank and tan_fuel = flr.flr_fuel;
 
 if vPriceVar is not null then
     begin
       -- Retrieve the previous unit price from the depot record or tank
       select fp.flr_price into vPricePrev
       from   r5fuelreceipts fp
       where  fp.flr_depot = flr.flr_depot and fp.flr_depot_org = flr.flr_depot_org
       and    fp.flr_tank = flr.flr_tank and fp.flr_fuel = flr.flr_fuel
	   and    fp.flr_date <= flr.flr_date
	   and    fp.flr_code <> flr.flr_code
       order by fp.flr_date desc,fp.flr_code desc
       FETCH FIRST ROW ONLY; 

       -- Calculate the allowed upper and lower deviation limits
       vPriceLower := vPricePrev * (1 - (vPriceVar / 100));
       vPriceUpper := vPricePrev * (1 + (vPriceVar / 100));
       /*vErrMsg := vPriceLower || ' - '||vPriceUpper;
	   vErrMsg := vPricePrev;
       raise err_val;*/
     
       if (flr.flr_price < vPriceLower or flr.flr_price > vPriceUpper) then
           vErrMsg := 'Price deviation exceeds allowed limit ( '||vPriceLower || ' - '||vPriceUpper||' ) in Tank ' || flr.flr_tank ||'. Please check.';
           raise err_val;
       /*else
           vErrMsg := 'Price Okay ' || flr.flr_price ;
           raise err_val;*/
       end if;
     exception when no_data_found then 
       null; --skip first receipt
     end;
  end if;
 
 --update tank average price using receipt price if it is 0
 if vPriceAvg = 0 then 
    update r5tanks 
    set tan_avgprice = flr.flr_price
    where tan_depot = flr.flr_depot and tan_depot_org = flr.flr_depot_org
    and   tan_code = flr.flr_tank and tan_fuel = flr.flr_fuel; 
 end if;
 

 
 /*vErrMsg := vPrice;
 raise err_val;*/
 
 
exception
when err_val then
   RAISE_APPLICATION_ERROR (-20003,vErrMsg) ;   
when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5fuelreceipts/Post Insert/10/'||substr(SQLERRM, 1, 500)) ;   
end;