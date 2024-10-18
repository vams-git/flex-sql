declare 
  dkl       r5docklines%rowtype;
  
  vByLot    r5parts.par_bylot%type;
  vLotCode  r5lots.lot_code%type;
  vCount    number;
begin
  select * into dkl from r5docklines where rowid=:rowid;
  /*****1. Update Lot****/
  select par_bylot into vByLot from r5parts
  where par_code = dkl.dkl_part and par_org = dkl.dkl_part_org;
  if vByLot = '+' then
     vLotCode := dkl.dkl_order_org || '-LS' || TO_CHAR(SYSDATE, 'YYMMDD');
     select count(1) into vCount from r5lots where lot_code = vLotCode;
     if vCount = 0 then
     insert into r5lots
     (lot_code, lot_desc, lot_org)
     values
     (vLotCode,'SAP ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD'),dkl.dkl_order_org);
     end if;
  else
    vLotCode :='*';
  end if;
  update r5docklines 
  set dkl_lot = vLotCode
  where dkl_dckcode = dkl.dkl_dckcode and dkl_line = dkl.dkl_line
  and   nvl(dkl_lot,' ')<> vLotCode;
  
  
exception 
when others then
 RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5DOCKLINES/Post Insert/200') ;
  --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;