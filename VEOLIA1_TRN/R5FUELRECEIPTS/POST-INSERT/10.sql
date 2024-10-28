declare 
 flr            r5fuelreceipts%rowtype;
 vPrice         r5fuelreceipts.flr_price%type;
 
 vErrMsg        varchar2(400);
 err_val        exception;

begin
 select * into flr from r5fuelreceipts where rowid=:rowid;
 select tan_avgprice into vPrice
 from r5tanks
 where tan_depot = flr.flr_depot and tan_depot_org = flr.flr_depot_org
 and   tan_code = flr.flr_tank and tan_fuel = flr.flr_fuel;
 if vPrice = 0 then 
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