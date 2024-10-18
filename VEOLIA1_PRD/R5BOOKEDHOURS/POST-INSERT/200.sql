declare 
  boo       r5bookedhours%rowtype;
  vOrg      r5organization.org_code%type;
  vOrder    r5orderlines.orl_order%type;
  vOrdline  r5orderlines.orl_ordline%type;
  
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
  
  checkresult        varchar2(4);
  iErrMsg            varchar2(500);
  err_overrecv       exception;
  vReceiptQty        varchar2(50);
  
begin
  select * into boo from r5bookedhours where rowid=:rowid;
  /*****1. Update Booked User in Udfchar30****/
  update r5bookedhours 
  set boo_udfchar30 = nvl(boo_udfchar30,o7sess.cur_user)
  where boo_code = boo.boo_code
  and nvl(boo_udfchar30,' ')<> nvl(boo_udfchar30,o7sess.cur_user);

  update r5bookedhours 
  set boo_udfchar30 = nvl(boo_udfchar30,o7sess.cur_user),
       boo_udfchar03 = boo.boo_mrc
  where boo_code = boo.boo_code
  and  boo_person is not null
  and nvl(boo_udfchar03,' ') <>boo.boo_mrc;
  
  /****2. Check Over Receipt Tolerance*******/
  if boo.boo_person is null and boo.boo_misc = '-' and boo.boo_routeparent is null 
    --and boo.boo_correction ='-' then
    and nvl(boo.boo_orighours,boo.boo_hours) > 0 THEN 
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
    
    /*if vOrlType = 'SF' then
       vNewValue := nvl(boo.boo_orighours,boo.boo_cost);
    else
       vNewValue := nvl(boo.boo_orighours,boo.boo_hours) * vPrice;
    end if;*/
    /****1. Check number of decimal***********/
    vReceiptQty := to_char(nvl(boo.boo_orighours,boo.boo_hours));
    if instr(vReceiptQty,'.') > 0 then
      if length(vReceiptQty) - instr(vReceiptQty,'.') > 3 then
         iErrMsg := 'Please note Receipting quantity or values in S/4 HANA can contains only3 decimals. Please adjust your record accordingly and re-submit.';
         raise err_overrecv;
      end if;
    end if;
    
    vNewValue := nvl(boo.boo_orighours,boo.boo_hours) * boo.boo_rate;
    vTotalRecvValue := vRecvValue + nvl(vNewValue,0);
     
    IF o7getorgoption('OVERRECV',vOrg,checkresult )  = 'NO' then
       if vTotalRecvValue > vOrderValue then
            iErrMsg := 'Receipt Value cannot be greater than the order value on the purchase order.';
            raise err_overrecv;
       end if;
    ELSE
       begin
          select opa_desc into vTolerancePer
          from r5organizationoptions WHERE OPA_CODE='PORECVP' AND OPA_ORG = vOrg;
       exception when no_data_found then
           vTolerancePer :=0;
       end;
       vToleranceValue :=  vOrderValue * to_number(vTolerancePer) * 0.01;
       if vTotalRecvValue - vOrderValue > vToleranceValue then
            iErrMsg := 'Receipt Value cannot be greater than the '||vTolerancePer||'% of order value on the purchase order.';
            raise err_overrecv;
       end if; 
       END IF;
  end if;
    
exception 
when err_overrecv then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/200' ||SQLCODE || SQLERRM);
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;