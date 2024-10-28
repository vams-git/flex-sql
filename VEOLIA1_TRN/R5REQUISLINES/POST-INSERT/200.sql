declare
 rql               r5requislines%rowtype;
 v_Org             r5organization.org_code%type;
 v_par_udfchar01   r5parts.par_udfchar01%type;
 vStoreClass           r5stores.str_class%type;

 err_val          exception;
 iErrMsg          varchar2(500);
 
begin
  select * into rql from r5requislines where rowid=:rowid;
  select req_org,str_class into v_Org,vStoreClass
  from r5requisitions,r5stores
  where req_code = rql.rql_req
  and   req_tocode = str_code and str_org = req_org ;
  
  if v_Org in ('HWC','WYU','GER','ROS','WCC','STA','VEO','WSL','WBP','BEN','BAL','GSP','BRK','RRM','QTN','KIL','RUA','THC','TTB','CHB','WLT','WEW','WOO','WLT','SBW','CFA','SWP','TAS','VIC','WAU','WAR','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP','DOC','BAR','CGC','FCG','SPF') then
    
     if nvl(vStoreClass,' ') <> 'GIF' then
         if rql.rql_type in ('PS') and  rql.rql_part  is not null then
           select par_udfchar01 into v_par_udfchar01 from r5parts where par_code = rql.rql_part and par_org = rql.rql_part_org;
           
           if  (v_par_udfchar01 = 'ZSPA' and rql.rql_costcode not like '%-600%')
             or  nvl(v_par_udfchar01,' ') not in ('ZSPA') and rql.rql_costcode like '%-600%' then
             
            iErrMsg := 'Please note for this contract, the Inventory cost code -600- should only be used for spare part going to the stock.
                     Please adjust either the part number or the Cost Code.';
            raise err_val;
           end if;
         end if;
         
         if rql.rql_type not in ('PS') and rql.rql_costcode like '%-600%' then
            iErrMsg := 'Please note for this contract cost code containing -600- should only be used for inventory purchases. 
                        Please adjust the cost code to another value.';
            raise err_val;
         end if;
      end if;
      
      if nvl(vStoreClass,' ') = 'GIF' then 
         if rql.rql_costcode like '%-600%' then
            iErrMsg := 'Please note for this contract cost code containing -600- should not use for GIF store purchase. 
                        Please adjust the cost code to another value.';
            raise err_val;
         end if;
      end if;
     
  end if;
 
 
exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5REQUISLINES/200/I - '||iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5REQUISLINES/200/I - ') ;
end;
