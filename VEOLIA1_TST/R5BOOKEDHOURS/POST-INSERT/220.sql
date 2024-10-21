declare 
   boo           r5bookedhours%rowtype;
   vOrder        r5orders.ord_code%type;
   vOrdLine      r5orderlines.orl_ordline%type;
   vRetnQty      r5bookedhours.boo_hours%type;
   vTotalInvQty  r5invoicelines.ivl_invqty%type;
   vRecvQty      r5bookedhours.boo_hours%type;
   
   iErrMsg            varchar2(500);
   err_validate      exception;
   
begin
  select * into boo from r5bookedhours where rowid =:rowid;
  if boo.boo_person is null and boo.boo_misc = '-' and boo.boo_routeparent is null  then
    if nvl(boo.boo_orighours,boo.boo_hours) < 0  then 
      vRetnQty := nvl(boo.boo_orighours,boo.boo_hours);
      begin
        select orl_order,orl_ordline,
        decode(orl_type,'SF',orl_recvvalue,orl_recvqty),
        orl_udfnum04
        into   vOrder,vOrdLine,
        vRecvQty,vTotalInvQty
        from r5bookedhours boo,r5activities,r5orderlines
        where boo_event = act_event and boo_act = act_act
        and   ((orl_order = boo_order and orl_ordline = boo_ordline)
             or(orl_order = act_order and orl_ordline = act_ordline)) 
        and  nvl(boo_routeparent,' ') = ' '
        and  boo.rowid=:rowid;
        --and boo.boo_code = 1036383;
      exception when no_data_found then
        return;
      end;
      
      --iErrMsg := 'Retn:'||vRetnQty||' vRecvQty:'||vRecvQty||' vTotalInvQty:'||vTotalInvQty;
     -- raise err_validate;

       if abs(vRetnQty) > nvl(vRecvQty,0) - nvl(vTotalInvQty,0) then
          iErrMsg := 'Can not return service due to PO line has been invoiced!';
          raise err_validate;
      end if;
   end if;
 end if;

exception
when err_validate then 
  RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
   RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/220' ||SQLCODE || SQLERRM);
end; 
