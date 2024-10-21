declare 
 fli        r5fuelissues%rowtype;
 vDepClass  r5depots.dep_class%type;
 
 vErrMsg    varchar2(400);
 err_val    exception;

begin
 select * into fli from r5fuelissues where rowid=:rowid;
 select nvl(dep_class,' ') into vDepClass from r5depots where dep_code = fli.fli_depot;
 if vDepClass in ('GIF','CRD') then
   if fli.fli_udfnum01 is null then
      vErrMsg := 'Please fill in price for fuel issued by card.';
      raise err_val;
   end if;
   
   if fli.fli_udfnum01 is not null then
      update r5fuelissues
      set fli_price = fli.fli_udfnum01
      where fli_code = fli.fli_code;  
   end if;
 end if;
 
 if vDepClass not in ('GIF','CRD') then
   if nvl(fli.fli_price,0) = 0 then
      vErrMsg := 'Issue Price is 0, please contact Administrator';
      raise err_val;
    end if;
 end if;
 
exception
when err_val then
   RAISE_APPLICATION_ERROR (-20003,vErrMsg) ;   
when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5fuelissues/Post Insert/5/'||substr(SQLERRM, 1, 500)) ;   
end;