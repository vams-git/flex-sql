declare 
  res             r5reservations%rowtype;
  vStrGrp         r5stores.str_pricecode%type;
  vStrGrpCls      r5classes.cls_code%type;
  vStockSrcType   r5stores.str_udfchar01%type;
  
  vDestStore      r5stores.str_code%type;
  vDestStoreOrg   r5stores.str_org%type;
  vSrcStore       r5stores.str_code%type;
  vSrcStoreOrg    r5stores.str_org%type;
  
  vTransQty       r5translines.trl_qty%type;
  vRemainResQty   r5translines.trl_qty%type;
  vTotalTransQty  r5translines.trl_qty%type;
  vGetAlloc       varchar2(2);
  allocateqty     r5translines.trl_qty%type;
  vBinAvaQty      r5translines.trl_qty%type;
  vTrlStore        r5translines.trl_store%type;
  vPart            r5parts.par_code%type;
  vPartOrg         r5parts.par_org%type;
  vBin             r5bins.bin_code%type;
  vLot             r5lots.lot_code%type;
  vPrice           r5translines.trl_price%type;
  vDestStorePrice  r5translines.trl_price%type;
  vIO              r5translines.trl_io%type;
  vWO              r5events.evt_code%type;
  vWOAct           r5activities.act_event%type;
  vWOCostCode      r5events.evt_costcode%type;
  vWOProj          r5events.evt_project%type;
  vWOProjBud       r5events.evt_projbud%type;
  
  
  vStrIssTraCode   r5transactions.tra_code%type;
  vStrRecTraCode   r5transactions.tra_code%type;
  vIssTraCode      r5transactions.tra_code%type; 
  trancode         r5transactions.tra_code%type;
  vDesc            r5transactions.tra_desc%type;
  
  vCurUser        varchar2(30);
  vLocTimeTime    date;
  vUtcTime        date;
  
  --get bin/lot/qty
  cursor cur_bis (vPart varchar2,vPartOrg varchar2,vStore varchar2) is 
  select * from (
  select bis_bin, lot_code,sum(bis_qty) as bis_sumqty
  from   r5binstock b left outer join r5lots on (bis_lot = lot_code)
  where  bis_part = vPart AND bis_part_org = vPartOrg AND bis_store = vStore
  AND    bis_bin != COALESCE((SELECT sto_defaultreturnbin
                                      FROM r5stock
                                      WHERE sto_part = b.bis_part
                                      AND sto_part_org = b.bis_part_org
                                      AND sto_store = b.bis_store
                                      AND COALESCE(sto_preventissuedefrtnbin, '-') = '+'),'#')
  group  by bis_bin,lot_code
  ) order by bis_sumqty desc;
  
  iErrMsg            varchar2(500);
  err_validate       exception;
  chk                varchar2(3);
  
PROCEDURE insert_transactions(vTraOrg varchar2,vTransType varchar2) IS
BEGIN
   r5o7.o7maxseq( trancode, 'TRAN', '1', chk );
   insert into  r5transactions
   (tra_org,tra_code,tra_desc,tra_advice,tra_class,tra_type,tra_rtype,tra_auth,tra_date,tra_status,tra_rstatus,
    tra_fromentity,tra_fromrentity,tra_fromtype,tra_fromrtype,tra_fromcode,tra_fromcode_org,
    tra_toentity,tra_torentity,tra_totype,tra_tortype,tra_tocode,tra_tocode_org,
    tra_created,tra_lastsaved,tra_sourcesystem)
    values
    (vTraOrg,trancode,vDesc,vWO,null,vTransType,vTransType,vCurUser,vLocTimeTime,'A','A',
    'STOR','STOR','*','*',vSrcStore,vSrcStoreOrg,
    'STOR','STOR','*','*',vDestStore, vDestStoreOrg,
    vUtcTime,vUtcTime,'VAMS_STOS');
 
    if vTransType = 'RECV' then
       vIO := 1;
       vTrlStore := vDestStore;
       vBin := '*';
       vLot := '*';
       vStrRecTraCode := trancode;
    else
       vIO := -1;
       vTrlStore := vSrcStore;
       vStrIssTraCode := trancode;
    end if;
     
    insert into r5translines
    (trl_trans,trl_type,trl_rtype,trl_line,trl_date,trl_part,trl_part_org,
     trl_lot,trl_bin,trl_store, trl_price,trl_avgprice,trl_qty,trl_io,
     trl_created, trl_lastsaved)
     values
    (trancode,vTransType,vTransType,1,vLocTimeTime,vPart,vPartOrg,
     vLot,vBin,vTrlStore,vPrice,vPrice,vTransQty,vIO,
     vUtcTime,vUtcTime);

   
END;

PROCEDURE issue_transaction IS
BEGIN
  r5o7.o7maxseq( trancode, 'TRAN', '1', chk );
  vIssTraCode := trancode;
  insert into  r5transactions
  (tra_org,tra_code,tra_desc,tra_advice,tra_class,tra_type,tra_rtype,tra_auth,tra_date,tra_status,tra_rstatus,
  tra_fromentity,tra_fromrentity,tra_fromtype,tra_fromrtype,tra_fromcode,
  tra_toentity,tra_torentity,tra_totype,tra_tortype,tra_tocode,
  tra_created,tra_lastsaved,tra_sourcesystem)
  values
  (vDestStoreOrg,trancode,'I',vWO,null,'I','I',vCurUser,vLocTimeTime,'A','A',
  'STOR','STOR','*','*',vDestStore,
  'EVNT','EVNT','*','*',vWO,
  vUtcTime,vUtcTime,'VAMS_STOS');
  
   insert into r5translines
  (trl_trans,trl_type,trl_rtype,trl_line,trl_date,trl_part,trl_part_org,
   trl_lot,trl_bin,trl_store, trl_price,trl_avgprice,trl_qty,trl_io,
   trl_event,trl_act,trl_costcode,trl_project,trl_projbud,
   trl_created, trl_lastsaved)
   values
  (trancode,'I','I',1,vLocTimeTime,vPart,vPartOrg,
   vLot,vBin,vTrlStore,vDestStorePrice,vDestStorePrice,vTransQty,-1,
   vWO,vWOAct,vWOCostCode,vWOProj,vWOProjBud,
   vUtcTime,vUtcTime
  );
  
END;

begin
  select * into res from r5reservations where rowid=:rowid;
  --WHERE ROWNUM<=1;
  --validate store group
  begin
  select str_udfchar01,str.str_pricecode,str_code,str_org
  into vStockSrcType,vStrGrp,vDestStore,vDestStoreOrg
  from r5stores str
  where str.str_code = res.res_store;
  exception when no_data_found then
    return;
  end;
  --get source store with same store group
  if vStockSrcType like 'STOREGRP%' then
  --if vStrGrp is not null and vStrGrpCls = 'STOS' then
    begin
     select str_code,str_org
     into   vSrcStore,vSrcStoreOrg
     from   r5stores str
     where  str.str_pricecode = vStrGrp
     and    nvl(str.str_udfchkbox01,'-') = '+';
     --and    str.str_code <> vDestStore;
    exception when no_data_found then
      iErrMsg:= 'Matching store is not found in System!';
      raise err_validate;
    when others then
      iErrMsg:= 'Matching store is not found in System!' || substr(SQLERRM, 1, 500);
    
      raise err_validate;
    end;
    if vSrcStore is null then
       iErrMsg:= 'Matching store is not found in System!';
       raise err_validate;
    end if;
  
  
  --get WO information
  --Insert issue part agaisnt WO
  vWO := res.res_event;
  vWOAct := res.res_act;
  vWOProj := res.res_project;
  vWOProjBud := res.res_projbud;
  select evt_costcode into vWOCostCode from r5events where evt_code = res.res_event;
    
  --get source bin by qty order desc
  vTransQty := 0;
  vRemainResQty := res.res_qty;
  vTotalTransQty := 0;
  vGetAlloc := 'N';
  for  rec_bis in cur_bis(res.res_part,res.res_part_org,vSrcStore) loop
       if vRemainResQty <= 0 then
           exit;
       end if;
       --get allocated qty
       if vGetAlloc = 'N' then
           begin
            SELECT  SUM( NVL( r.res_allqty, 0 ) )
            INTO   allocateqty
            FROM   r5reservations r
            WHERE  r.res_part     = res.res_part
            AND    r.res_part_org = res.res_part_org
            AND    r.res_store    = vSrcStore;
           exception when others then
             allocateqty := 0;
           end;
           vGetAlloc := 'Y';
        else
           allocateqty := 0;
        end if;
        
        vBinAvaQty := rec_bis.bis_sumqty - NVL(allocateqty,0); 
        if vBinAvaQty > 0 then
            if vBinAvaQty >= vRemainResQty then
               vTransQty := vRemainResQty;
            else 
               vTransQty := vBinAvaQty;
            end if;
         end if;
         if vTransQty > 0 then
            --insert store to store transfer
            begin
                vCurUser := nvl(o7sess.cur_user,'R5');
                vUtcTime := sysdate;
                vDesc := substr('Transfer for Reserved part ' || res.res_part || ' for WO ' || res.res_event,1,80);
                
                vBin := rec_bis.bis_bin;
                vLot := rec_bis.lot_code;
                vPart := res.res_part;
                vPartOrg := res.res_part_org;
                
                vPrice := o7getprc(vSrcStore,vPart,vPartOrg,vSrcStoreOrg,'A',null,null);
                --Insert Issue Sourcestore org
                vLocTimeTime := o7gttime(vSrcStoreOrg);
                insert_transactions(vSrcStoreOrg,'I');
                --Insert receive dest org
                vLocTimeTime := o7gttime(vDestStoreOrg);
                insert_transactions(vDestStoreOrg,'RECV');
                
                vTotalTransQty := vTotalTransQty + vTransQty;
                
            exception when others then
                iErrMsg := 'Error in Flex r5reservations/Post Insert/10/'||substr(SQLERRM, 1, 500);
                raise err_validate;
            end;  
            vRemainResQty := vRemainResQty - vTransQty;
         end if;
  end loop;
  
  if vRemainResQty > 0 then
     iErrMsg := 'Stock qty is lower then requested qty!';
     raise  err_validate;
  end if;
  
  if vTotalTransQty > 0 then
     vDestStorePrice := o7getprc(vDestStore,vPart,vPartOrg,vDestStoreOrg,'A',null,null);
     issue_transaction;
     update r5translines set trl_udfchar26 = vIssTraCode where trl_trans in (vStrIssTraCode,vStrRecTraCode);
  end if;
 
 end if; --vStockSrcType like 'STOREGRP% 


exception 
  when err_validate then
       RAISE_APPLICATION_ERROR (-20001,iErrMsg);
  when others then
       RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex r5reservations/Post Insert/10/'||substr(SQLERRM, 1, 500)) ;     
end;
