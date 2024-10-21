declare 
 trl            r5translines%rowtype;

  vMultiply      r5orderlines.orl_multiply%type;
  vReturnQtyUOP  r5translines.trl_qty%type;

begin
  select * into trl from r5translines where rowid=:rowid;
  
  --return part from work order to store
  if trl.trl_type in ('RETN','RECV') and trl.trl_order is not null then
     select orl_multiply into vMultiply
     from r5orderlines
     where orl_order_org = trl.trl_order_org and orl_order = trl.trl_order
     and   orl_ordline = trl.trl_ordline;

     vReturnQtyUOP := abs(nvl(trl.trl_origqty,trl.trl_qty)) / nvl(vMultiply,1);

     --vOrlComment  := dbms_lob.substr(R5REP.TRIMHTML(trl.trl_order ||'#'||trl.trl_order_org||'#'||trl.trl_ordline,'PORL','*','EN','10'),3500,1);
     if nvl(trl.trl_udfnum01,0) <> nvl(vReturnQtyUOP,0) then
       update r5translines 
       set    trl_udfnum01 = vReturnQtyUOP
       where  rowid=:rowid;
     end if;
  end if;
  
exception
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5translines/Post Update/220') ;  
end;