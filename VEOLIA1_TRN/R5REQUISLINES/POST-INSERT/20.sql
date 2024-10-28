declare 
   rql              r5requislines%rowtype;
   vCount           number;
   vOrg             r5organization.org_code%type;
   vDeladdress      r5requisitions.req_deladdress%type;
   vManufactPart    r5partmfgs.mfp_manufactpart%type;
   vManufact        r5manufacturers.mfg_code%type;
   vManufactDesc    r5manufacturers.mfg_desc%type;
   vNewDesc         varchar2(2000);
   vSupPart         varchar2(200);
   vSupPartDesc     varchar2(200);
   vSupPartInfo     varchar2(200);
   vComm            long;
   vEvtDesc         r5events.evt_desc%type;
   vCommEvt         varchar2(400);
   vELine           r5addetails.add_line%type;
   vEText           varchar2(4000);
   
   vAddCode         r5addetails.add_code%type;
   vCPAPrice        r5requislines.rql_price%type;
   vSAPPartCode     r5parts.par_udfchar20%type;
   vPurUom          r5requislines.rql_uom%type;
   vMultiply        r5requislines.rql_multiply%type;
   vUOMPrice        r5requislines.rql_price%type;
begin
  select * into rql from r5requislines where rowid=:rowid;
  select req_org,req_deladdress
  into vOrg,vDeladdress
  from r5requisitions where req_code = rql.rql_req;
   /**1. Generate Part Comment***/
  if rql.rql_event is not null then
     select evt_desc into vEvtDesc 
     from r5events where evt_code = rql.rql_event;
     vCommEvt := vEvtDesc || chr(10) || 'VAMS WO:'|| rql.rql_event;
  end if;
  
  if rql.rql_part is not null then
   begin
      select mfp_manufactpart ,mfp_manufacturer,r5o7.o7get_desc('EN','MANU',mfp_manufacturer,'','')
      into vManufactPart,vManufact,vManufactDesc
      from r5partmfgs
      where mfp_part = rql.rql_part
      and   mfp_part_org = rql.rql_part_org and mfp_primary = '+';
      --and rownum<=1;
      --and   mfp_manufacturer not in ('CAUS-TBD');
    exception when no_data_found then
      vManufactPart := null;
      vManufact     := null;
      vManufactDesc := null;
      when others then 
      vManufactPart := null;
      vManufact     := null;
      vManufactDesc := null;  
    end;

    begin
        select cat_ref,cat_desc,cat_puruom,cat_multiply
        into vSupPart,vSupPartDesc,vPurUom,vMultiply
        from r5catalogue
        where cat_part = rql.rql_part
        and   cat_supplier = rql.rql_supplier
        and   rownum <= 1;
    exception when no_data_found then
        vSupPart := null;
        vSupPartDesc := null;
    end;

    
    if vSupPart is not null or vSupPartDesc is not null then
       select  chr(10) || 'Supplier Information:' ||  vSupPartDesc || nvl2(vSupPart,' N#: ' || vSupPart,null)
       into vSupPartInfo from dual;
    end if;

    select
    par_udfchar24||','||r5o7.o7get_desc('EN','UOM',par_uom,'','') ||
    decode(par_udfchar27,null,null,','||par_udfchar27)||
    decode(par_udfchar26,null,null,','||par_udfchar26)||
    decode(par_udfchar25,null,null,','||par_udfchar25)||
    decode(par_udfchar30,null,null,','||par_udfchar30)||
    decode(vManufactDesc,null,null,','||vManufactDesc)||
    decode(vManufactpart,null,null,',P/N:'||vManufactPart)||
    decode(vSupPartInfo,null,null,','||vSupPartInfo)
    into vComm
    from r5parts
    where par_code = rql.rql_part and par_org = rql.rql_part_org;

    if rql.rql_event is not null then 
      vComm  :=vComm || chr(10) || --vCommEvt;
      'VAMS WO:' || rql.rql_event || ' ' || vEvtDesc || '. Activity:' || rql.rql_act;
    end if;
    
    vAddCode :=  rql.rql_req || '#' || rql.rql_reqline;
    select count(1) into vCount from R5ADDETAILS
    where add_entity ='REQL' and add_type ='*' and add_code =vAddCode;
    if  vCount = 0 then
    INSERT INTO R5ADDETAILS(
          ADD_ENTITY,
          ADD_RENTITY,
          ADD_TYPE,
          ADD_RTYPE,
          ADD_CODE,
          ADD_LANG,
          ADD_LINE,
          ADD_PRINT,
          ADD_TEXT,
          ADD_CREATED,
          ADD_USER)
     VALUES(
          'REQL',
           'REQL',
          '*',
          '*',
          vAddCode,
          'EN',
          1,
          '+',
          vComm,
          --SYSDATE,
          o7gttime(vOrg),
          O7SESS.CUR_USER);
      end if;
  end if;
  
  if rql.rql_type like 'S%' and rql.rql_event is not null then
    vAddCode :=  rql.rql_event|| '#'|| rql.rql_act;
    select count(1) into vCount from R5ADDETAILS
    where add_entity ='EVNT' and add_type ='*' and add_code =vAddCode and add_lang = 'EN';
    if  vCount = 0 then
       INSERT INTO R5ADDETAILS(
          ADD_ENTITY,
          ADD_RENTITY,
          ADD_TYPE,
          ADD_RTYPE,
          ADD_CODE,
          ADD_LANG,
          ADD_LINE,
          ADD_PRINT,
          ADD_TEXT,
          ADD_CREATED,
          ADD_USER)
      VALUES(
          'EVNT',
          'EVNT',
          '*',
          '*',
          vAddCode,
          'EN',
          10,
          '+',
          vCommEvt,
          --SYSDATE,
          o7gttime(vOrg),
          O7SESS.CUR_USER);
      else
        select add_line,add_text into vELine,vEText from 
        (
        select add_line,
        dbms_lob.substr(R5REP.TRIMHTML(add_code,add_entity,add_type,'EN',add_line),3500,1) as add_text
        from r5addetails
        where add_entity ='EVNT' and add_type ='*' and add_code =vAddCode and add_lang = 'EN'
        order by add_line
        ) where rownum <= 1;
        if vEText not like '%'||vCommEvt then
           vCommEvt := vEText ||chr(10)|| vCommEvt;
           update r5addetails
           set   add_text = vCommEvt
           where add_entity ='EVNT' and add_type ='*' and add_code =vAddCode and add_lang = 'EN';
        end if;
        
        
      end if; --if  vCount = 0 then
  end if; --if rql.rql_type like 'S%' and rql.rql_event is not null then
  
  /**4. Get purchase contract price Need rework for PURUOM****/
  /*vUOMPrice := rql.rql_price;
  if rql.rql_part is not null then
    begin
     select cpa.cpa_price into vCPAPrice
     from r5contracts con,r5conparts cpa
     where con.con_code = cpa.cpa_contract
     and   con.con_rstatus  ='A'
     and   trunc(sysdate) between con.con_start and con.con_end
     and   con.con_supplier = rql.rql_supplier and con.con_supplier_org = rql.rql_supplier_org
     and   cpa.cpa_part = rql.rql_part and cpa.cpa_part_org = rql.rql_part_org
     and   cpa.cpa_puruom = rql.rql_uom;
    exception  when no_data_found then
      vCPAPrice := null;
    when others then
      vCPAPrice := null;
    end;
    
    if vCPAPrice is not null then
       vUOMPrice := vCPAPrice;
       update r5requislines 
       set    rql_price = vCPAPrice
       where  rowid =:rowid
       and    rql_price <> vCPAPrice;
    end if;
  end if;*/

  
  
  /**2.Auto fill in part manfu information**/
  --For Inserting
  if vManufactPart is not null and vManufact is not null then
    update r5requislines 
     set   RQL_MANUFACTURER = nvl(RQL_MANUFACTURER,vManufact),
           RQL_MANUFACTPART = nvl(RQL_MANUFACTPART,vManufactPart)
    where  rowid =:rowid
    and    (nvl(RQL_MANUFACTURER,' ')<> nvl(nvl(RQL_MANUFACTURER,vManufact), ' ')
     or     nvl(RQL_MANUFACTPART,' ') <> nvl(nvl(RQL_MANUFACTPART,vManufactPart),' ')); 
  end if;
  
  
  begin
    select par_udfchar20 into vSAPPartCode
    from r5parts where par_code = nvl(rql.rql_part,rql.rql_udfchar27)
    and par_org = 'CAUS' and par_notused ='-';
  exception when no_data_found then
    vSAPPartCode := null;
  end;
  
  update r5requislines
  set rql_udfchar20 = vSAPPartCode,
      rql_deladdress = nvl(rql_deladdress,vDeladdress)
  where rowid =:rowid
  and   (nvl(rql_udfchar20,' ') <> nvl(vSAPPartCode,' ')
       or nvl(rql_deladdress,' ') <> nvl(nvl(rql_deladdress,vDeladdress),' '));
 
exception 
 when others then
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requislines/Insert/20') ;  
end;