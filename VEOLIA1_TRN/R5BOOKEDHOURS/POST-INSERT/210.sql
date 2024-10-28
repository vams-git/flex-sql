declare 
  boo                r5bookedhours%rowtype;
  vOrg               r5organization.org_code%type;
  vOrder             r5orderlines.orl_order%type;
  vOrdline           r5orderlines.orl_ordline%type;
  
  vOrlType           r5orderlines.orl_type%type;
  vOrdQty            r5orderlines.orl_ordqty%type;
  vPrice             r5orderlines.orl_price%type;
  vOrderValue        r5orderlines.orl_price%type;
  vRecvQty           r5orderlines.orl_recvqty%type;
  vRecvValue         r5orderlines.orl_recvvalue%type;
  
  vNewValue          r5orderlines.orl_recvvalue%type;
  vTotalRecvValue    r5orderlines.orl_recvvalue%type;
  
  vTolerancePer      number;
  vToleranceValue    r5orderlines.orl_recvvalue%type;
  
  vReceiptCode       r5bookedhours.boo_code%type;
  vReceiptDate       r5bookedhours.boo_entered%type;
  
  checkresult        varchar2(4);
  iErrMsg            varchar2(500);
  err_validate       exception;
  
begin
  select * into boo from r5bookedhours where rowid=:rowid;
  if boo.boo_person is null and boo.boo_misc = '-' and boo.boo_routeparent is null  then
    /****3. Check Return Value*******/
    if nvl(boo.boo_orighours,boo.boo_hours) < 0 then 
     /****Pre-check for order information*******/
     begin
        select evt_org into vOrg from r5events where evt_code = boo.boo_event;
        
        select act_order,act_ordline
        into   vOrder,vOrdline
        from   r5activities
        where  act_event = boo.boo_event and act_act = boo.boo_act;
        
        select orl_type,orl_ordqty,orl_price,orl_ordqty * orl_price,nvl(orl_recvqty,0),nvl(orl_recvvalue,0)
        into   vOrlType,vOrdQty,vPrice,vOrderValue,vRecvQty,vRecvValue
        from   r5orderlines
        where  orl_order = nvl(boo.boo_order,vOrder) and orl_ordline = nvl(boo.boo_ordline,vOrdline);
    exception when no_data_found then
        return;
    end;

    vNewValue := nvl(boo.boo_orighours,boo.boo_hours);

    begin
     select boo_code,boo_entered 
     into vReceiptCode,vReceiptDate from
      (select boo_code,boo_entered
      from r5bookedhours,r5activities,r5orderlines
      where boo_event = act_event and boo_act = act_act
      and   orl_order = nvl(boo_order,act_order) and orl_ordline = nvl(boo_ordline,act_ordline)
      and nvl(boo_orighours,boo_hours) > 0
      and   boo_person is null and boo_misc = '-' and boo_routeparent is null 
      
      and   boo_event = boo.boo_event and boo_act = boo.boo_act
      and   orl_order = nvl(boo.boo_order,vOrder) and orl_ordline = nvl(boo.boo_ordline,vOrdline)
      and   trunc(boo_date) =  trunc(boo.boo_date)
      --and   decode(orl_type,'SF',nvl(boo_orighours,boo_cost),nvl(boo_orighours,boo_hours))= abs(vNewValue)
      and   nvl(boo_orighours,boo_hours) - nvl(boo_udfnum04,0) = abs(vNewValue)
      and   boo_udfchar26 is null
      order by boo_acd desc
      )where rownum <= 1;
      --Update Return code on Receipt Line
      update r5bookedhours
      set    boo_udfchar26 = boo.boo_code, boo_udfchar25 = '10'
      where  boo_code = vReceiptCode
      and    nvl(boo_udfchar26,' ')||nvl(boo_udfchar25,' ')<> boo.boo_code||'10';
      --Upldate Receipt Code on Return Line
      update r5bookedhours
      set    boo_udfchar26 = vReceiptCode,boo_udfchar25='10'
      ,boo_udfdate05=vReceiptDate
      where  boo_code = boo.boo_code
      and    (nvl(boo_udfchar26,' ')||nvl(boo_udfchar25,' ')<> boo.boo_code||'10' or boo_udfdate05 <>vReceiptDate);
    exception when no_data_found then
      iErrMsg := 'Service Correction value must be same as Receipt Transaction value. And Receipt line must be not invoiced.';
      raise err_validate;
    end;
    end if;
  end if;
    
exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/210' ||SQLCODE || SQLERRM);
end;
