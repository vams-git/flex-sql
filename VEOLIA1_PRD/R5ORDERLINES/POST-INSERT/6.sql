declare
   orl              r5orderlines%rowtype;
   vSourceCode      r5orders.ord_sourcecode%type;
   vSourceSystem    r5orders.ord_sourcesystem%type;
   vUOPUOM          r5orderlines.orl_puruom%type;
   vSAPUOM          u5sapuom.sum_sapinternalcode%type;
   vMultiply        r5orderlines.orl_multiply%type;
   vRqlQty          r5requislines.rql_qty%type;
   vRqlPrice        r5requislines.rql_price%type;
   vTaxRate         r5orderlines.orl_tottaxamount%type;
   vTaxAmount       r5orderlines.orl_tottaxamount%type;
   vLineComment     varchar2(4000);

begin
    select * into orl from r5orderlines where rowid=:rowid;
    select ord_sourcecode,ord_sourcesystem
    into vSourceCode,vSourceSystem
    from r5orders
    where ord_code = orl.orl_order;
    
    --Copy UOP/Multiple and recalution Ordqty 
    if vSourceSystem = 'SAP' and orl.orl_req is not null then
        select
        case when rql.rql_udfchar01 is not null then rql.rql_udfchar01
        else (select par_uom from r5parts where par_org = 'CAUS' and par_code = nvl(rql_part,rql_udfchar27)) end as rql_uop,
        nvl(rql_udfnum03,1) as rql_multiply,
        rql_qty,rql_price   
        into vUOPUOM, vMultiply,
        vRqlQty,vRqlPrice
        from r5requislines rql
        where rql_req = orl.orl_req and rql_reqline = orl.orl_reqline;
        
        begin
         select Sum_Sapinternalcode into vSAPUOM
         from u5sapuom,r5uoms
         where sum_uom = uom_code and uom_notused ='-'
         and sum_uom =  vUOPUOM
         and Sum_Sapinternalcode is not null
         and rownum <= 1;
       exception when no_data_found then
         vSAPUOM := vUOPUOM;
       end;
       if orl.orl_tax is not null then
          vTaxRate := o7gettax(orl.orl_tax,o7gttime(orl.orl_order_org));
          vTaxAmount := round(vRqlQty * vRqlPrice * vTaxRate / 100,2);
       end if; 
       if orl.orl_type not in ('SF') then
          update r5orderlines o
          set o.orl_puruom = vUOPUOM,
          o.orl_multiply = vMultiply,
          o.orl_price = vRqlPrice * vMultiply,
          o.orl_ordqty = vRqlQty,--orl.orl_ordqty * vMultiply,
          o.orl_tottaxamount = vTaxAmount,
          o.orl_sourcecode = vSourceCode,
          o.orl_sourcesystem = vSourceSystem,
          o.orl_udfchar02 = vSAPUOM
          where rowid = :rowid;
      else
          update r5orderlines o
          set o.orl_puruom = vUOPUOM,
          o.orl_multiply = vMultiply,
          o.orl_price = vRqlPrice,--orl.orl_ordqty * vMultiply,
          o.orl_ordqty = vRqlQty * vMultiply,--orl.orl_price,
          o.orl_tottaxamount = vTaxAmount,
          o.orl_sourcecode = vSourceCode,
          o.orl_sourcesystem = vSourceSystem,
          o.orl_udfchar02 = vSAPUOM
          where rowid = :rowid;
      end if;
        
        if orl.orl_type like 'S%' then
           update r5orderlines o
           set orl_udfchar27 = o.orl_udfchar20
           where rowid = :rowid;
        end  if;
        
        --Copy Requistion line comment to Purchase order line
        if orl.orl_type not in ('SF','ST') then
           --get requistion line comment
           begin
             select 
             dbms_lob.substr(TO_CLOB(
                 R5REP.TRIMHTML(add_code,add_entity,add_type,add_lang,add_line) 
                 ),3500,1)
             into vLineComment
             from r5addetails
             where add_entity ='REQL' 
             and add_code= orl.orl_req||'#'||orl.orl_reqline
             and add_lang ='EN'
             and rownum <=1;
           exception when no_data_found then
             vLineComment := null;
           end;
           
           if vLineComment is not null then
               delete from r5addetails
               where add_entity = 'PORL' 
               and   add_code = orl.orl_order||'#'||orl.orl_order_org||'#'||orl.orl_ordline;
               
               insert into r5addetails
               (add_entity,add_rentity,add_type,add_rtype,add_code,
               add_lang,add_line,add_print,add_text,add_created,add_user)
               values
               ('PORL','PORL','*','*',orl.orl_order||'#'||orl.orl_order_org||'#'||orl.orl_ordline,
               'EN',10,'+',vLineComment,o7gttime(orl.orl_order_org),O7SESS.cur_user);
           end if;
   
        end if;
        
    end if;
   

exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/insert/5/' ||SQLCODE || SQLERRM) ; 
end;