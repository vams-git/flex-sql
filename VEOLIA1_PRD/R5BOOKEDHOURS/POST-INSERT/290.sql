declare 
  boo             r5bookedhours%rowtype;
  
  vOrder          r5orderlines.orl_order%type;
  vOrdLine        r5orderlines.orl_ordline%type;
  vOrg            r5orderlines.orl_order_org%type;
  
  vSAPItemCode   r5parts.par_udfchar20%type;
  vPartDesc      r5parts.par_udfchar24%type;
  vOrlPurUOM     r5orderlines.orl_puruom%type;
  vDelAddress    r5orderlines.orl_deladdress%type;
  vRecvDate      r5dockreceipts.dck_recvdate%type;
  vSAPUOM        r5orderlines.orl_puruom%type;
  vEvent         r5events.evt_code%type;
  vAct           r5activities.act_act%type;


begin
  select * into boo from r5bookedhours where rowid=:rowid;
  if boo.boo_person is null and boo.boo_misc = '-'  then
    if boo.boo_routeparent is null then
       vEvent := boo.boo_event;
       vAct := boo.boo_act;
    else 
       select evt_parent into vEvent from r5events where evt_code = boo.boo_event;
       vAct := boo.boo_act;
    end if;
    
    begin
      if boo.boo_order is null then
        select act_order,act_ordline,act_order_org
        into vOrder,vOrdLine,vOrg
        from r5activities
        --where act_event = boo.boo_event and act_act = boo.boo_act;
        where act_event = vEvent and act_act = vAct;
      else
         vOrder := boo.boo_order;
         vOrdLine := boo.boo_ordline;
         vOrg := boo.boo_order_org;
      end if;
    exception when no_data_found then 
      vOrder := null;
      vOrdLine := null;
      vOrg := null;
    end;
     
    if vOrder is not null then
       select
       par_udfchar24,par_udfchar20,orl_deladdress, orl_puruom
       into 
       vPartDesc,vSAPItemCode,vDelAddress,vOrlPurUOM
       from r5orderlines,r5parts 
       where  par_code = nvl(orl_udfchar27,orl_udfchar20)  and par_org = 'CAUS'
       and   orl_order_org = vOrg and orl_order = vOrder
       and   orl_ordline = vOrdLine; 
       
       begin
         select Sum_Sapinternalcode into vSAPUOM
         from u5sapuom,r5uoms
         where sum_uom = uom_code and uom_notused ='-'
         and sum_uom =  vOrlPurUOM
         and Sum_Sapinternalcode is not null
         and rownum <= 1;
       exception when no_data_found then
         vSAPUOM := vOrlPurUOM;
       end;

       update r5bookedhours
       set 
       boo_udfdate01 = trunc(boo.boo_date),
       boo_udfchar06 = vSAPItemCode,
       boo_udfchar07 = vPartDesc,
       boo_udfchar08 = vSAPUOM,
       boo_udfchar09 = vDelAddress,
       boo_udfchar10 =  (select usr_emailaddress  from r5users where usr_code = o7sess.cur_user),
       boo_udfchar11 = r5o7.o7get_desc('EN','EVNT', vEvent,'', ''),
       boo_udfchar29 = boo.boo_code,
       boo_udfnum01 = nvl(boo.boo_orighours,boo.boo_hours)
       where boo_code = boo.boo_code;
       
   end if;
    
  end if;
exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/290/'  ||SQLCODE || SQLERRM) ;
end;