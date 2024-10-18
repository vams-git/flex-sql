declare 
 trl            r5translines%rowtype;
  --vOrlComment    varchar2(4000);
 
  vOrlComment    varchar2(80);
  vSAPItemCode   r5parts.par_udfchar20%type;
  vPartDesc      r5parts.par_udfchar24%type;
  vOrlPurUOM     r5orderlines.orl_puruom%type;
  vDelAddress    r5orderlines.orl_deladdress%type;
  vRecvDate      r5dockreceipts.dck_recvdate%type;
  vSAPUOM        r5orderlines.orl_puruom%type;
  vMultiply      r5orderlines.orl_multiply%type;
  vReturnQtyUOP  r5translines.trl_qty%type;
  vTraDate       r5transactions.tra_date%type;
  vReturnEmail   r5users.usr_emailaddress%type;
begin
  select * into trl from r5translines where rowid=:rowid;
  
  --return part from work order to store
  if trl.trl_type = 'RETN' and trl.trl_order is not null then
     select 
     case when orl_type in ('SF','ST') then dbms_lob.substr(R5REP.TRIMHTML(orl_event||'#'||orl_act,'EVNT','*','EN',10),80,1)
     else dbms_lob.substr(R5REP.TRIMHTML(orl_order||'#'||orl_order_org||'#'||orl_ordline,'PORL','*','EN',10),80,1) end
     ,par_udfchar24,par_udfchar20,orl_deladdress, orl_puruom,orl_multiply
     into vOrlComment
     ,vPartDesc,vSAPItemCode,vDelAddress,vOrlPurUOM,vMultiply
     from r5orders,r5orderlines,r5parts 
     where ord_code = orl_order and ord_org = orl_order_org
     and   orl_part = par_code and orl_part_org = par_org
     and   orl_order_org = trl.trl_order_org and orl_order = trl.trl_order
     and   orl_ordline = trl.trl_ordline;
     
     select tra_date into vTraDate from r5transactions where tra_code = trl.trl_trans;
     
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
     
     vReturnQtyUOP := abs(nvl(trl.trl_origqty,trl.trl_qty)) / nvl(vMultiply,0);

     --vOrlComment  := dbms_lob.substr(R5REP.TRIMHTML(trl.trl_order ||'#'||trl.trl_order_org||'#'||trl.trl_ordline,'PORL','*','EN','10'),3500,1);
     update r5translines 
     set    trl_udfdate01 = vTraDate,
            trl_udfnum01 = vReturnQtyUOP,
            trl_udfchar06 = vSAPItemCode,
            trl_udfchar07 = vPartDesc,
            trl_udfchar08 = vSAPUOM,
            trl_udfchar09 = vDelAddress,
            trl_udfchar29 = trl.trl_ordline,
            trl_udfchar28 = substr(vOrlComment,0,80)
     where  rowid=:rowid;
  end if;
  
  if trl.trl_type = 'RECV' and trl.trl_order is not null then
      begin
        select nvl(usr_emailaddress,usr_code) into vReturnEmail from r5users where usr_code = o7sess.cur_user
        and rownum<=1;
      exception when no_data_found then
        vReturnEmail:= o7sess.cur_user;
      end;
      update r5translines
      set trl_udfchar10 = substr(vReturnEmail,1,80)
      where rowid=:rowid
      and   nvl(trl_udfchar10,' ') <> nvl(vReturnEmail, ' ');
      
      update r5orderlines
      set orl_udfdate01 = o7gttime(trl.trl_order_org)
      where orl_order = trl.trl_order and orl_order_org = trl.trl_order_org and orl_ordline = trl.trl_ordline;
  end if;
  
exception
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5translines/Post Insert/210') ;  
end;