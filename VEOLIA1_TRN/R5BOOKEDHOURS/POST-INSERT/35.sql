declare 
   boo r5bookedhours%rowtype;
   vi_sumudf r5bookedhours.boo_cost%type;
   vi_totalcost r5bookedhours.boo_cost%type;
   vi_locale r5organization.org_locale%type;
   DB_ERROR exception;
   iErrMsg  varchar2(400);
begin
   select * into boo from r5bookedhours where rowid =:rowid;
   /*select org_locale into vi_locale
   from r5events,r5organization 
   where evt_org = org_code
   and   evt_code = boo.boo_event;
  
  if vi_locale = 'NZ' then*/
  begin
    select 
    case when orl_type = 'SF' then nvl(boo_orighours,boo_cost)
    else orl_price*nvl(boo_orighours,boo_hours) end 
    into vi_totalcost
    from r5bookedhours boo,r5activities,r5orderlines
    where boo_event = act_event and boo_act = act_act
    and   orl_order= nvl(boo_order,act_order) and orl_ordline = nvl(boo_ordline,act_ordline) 
    and   boo_person is null
    and   boo.rowid = :rowid;
  exception when no_data_found then
    return;
  end;
  if vi_totalcost < 0 then return; end if;
  
   
  begin 
    vi_sumudf := to_number(nvl(boo.boo_udfchar01,0))
               + to_number(nvl(boo.boo_udfchar02,0))
               + to_number(nvl(boo.boo_udfchar03,0)) 
               + to_number(nvl(boo.boo_udfchar04,0));
  exception when others then 
    iErrMsg := 'Please enter number for Costs';
    raise DB_ERROR;
  end ;
  if vi_sumudf > vi_totalcost then
    iErrMsg := 'The components costs exceed the total value received. Please adjust accordingly.';
    raise DB_ERROR;
  end if;
 --end if; 
exception 
  WHEN DB_ERROR THEN
     RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
  when others then
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5bookedhours/Insert/35/' ||SQLCODE || SQLERRM) ; 
end;