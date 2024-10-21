declare 
  trl            r5translines%rowtype;
  vOrg           r5transactions.tra_org%type;
  vTraStatus     r5transactions.tra_status%type;
  vSupplier      r5transactions.tra_fromcode%type;
  vSupplierOrg   r5transactions.tra_fromcode_org%type;
  vParClass      r5parts.par_class%type;
  vCnt           number;
  vFlrCode       r5fuelreceipts.flr_code%type;
  vTraCode       r5transactions.tra_code%type;
  vDesc          r5transactions.tra_desc%type;
  vOrigQty       r5binstock.bis_qty%type;
  vFuelReceiptQty r5binstock.bis_qty%type;
  vDepCode       r5depots.dep_code%type;
  
  iErrMsg        varchar2(200);
  valErr         exception;
  
begin
  select * into trl from r5translines where rowid=:rowid;
  if trl.trl_part is not null and trl.trl_type in ('RECV','RETN') and trl.trl_order is not null  then
     select par_class into vParClass from r5parts where par_code = trl.trl_part and par_org = trl.trl_part_org;
     if vParClass IN ('FUEL','ADBLUE') then
          if trl.trl_type = 'RECV' then
            begin
              select tra_org,tra_status,tra_fromcode,tra_fromcode_org
              into vOrg,vTraStatus,vSupplier,vSupplierOrg
              from r5transactions 
              where tra_code = trl.trl_trans
              and tra_fromentity ='COMP' and tra_status ='A'
              and tra_type ='RECV';
            exception when no_data_found then
              return;
            end;
            
            select count(1) into vCnt
            from r5tanks,r5fuels
            where tan_fuel = fue_code
            and   tan_depot = trl.trl_udfchar11 and tan_depot_org = vOrg
            and   tan_code =  trl.trl_udfchar12
            and   fue_code =  trl.trl_udfchar13
			and   fue_udfchar02 = trl.trl_part
            and   tan_notused = '-';
            
             if vCnt = 0 then
                iErrMsg := 'Please select valid Depot,Tank, Fuel for fuel part receipt.';
                raise valErr;
             else
               vFuelReceiptQty := nvl(trl.trl_origqty,trl.trl_qty);
               insert into r5fuelreceipts 
               (flr_depot,flr_depot_org,flr_tank,flr_fuel,flr_date,flr_qty,flr_price,flr_supplier,flr_supplier_org,flr_reference)
               values
               (trl.trl_udfchar11,vOrg,trl.trl_udfchar12,trl.trl_udfchar13,trl.trl_date,vFuelReceiptQty,trl.trl_price,vSupplier,vSupplierOrg,trl.trl_trans)
               RETURNING flr_Code INTO vFlrCode;
               
               update r5docklines dk
               set    dkl_udfchar14 = vFlrCode
               where  dk.dkl_dckcode = trl.trl_dckcode and dk.dkl_line = trl.trl_dckline
               and    nvl(dkl_udfchar14,' ') <> nvl(vFlrCode,' ');
               
               update r5translines
               set    trl_udfchar14 = vFlrCode
               where  rowid =:rowid
               and    nvl(trl_udfchar14,' ') <> nvl(vFlrCode,' ');
               
               /*select s5trans.nextval into vTraCode from dual;
               vDesc := 'From PO ' || trl.trl_order || '-Fuel Recv-' || trl.trl_trans;
               
               select sum(bis_qty) into vOrigQty 
               from r5binstock b
               where b.bis_part = trl.trl_part and b.bis_part_org = trl.trl_part_org
               and   b.bis_store = trl.trl_store
               and   b.bis_bin = trl.trl_bin and b.bis_lot = trl.trl_lot;
               --if vOrigQty >= vFuelReceiptQty then
               --end if;
              
               --vOrigQty := vOrigQty + nvl(trl.trl_origqty,trl.trl_qty);
               
               insert into r5transactions
               (tra_code,tra_desc,tra_type,tra_rtype,tra_auth,tra_date,tra_status,tra_rstatus,
               tra_fromentity,tra_fromrentity,tra_fromtype,tra_fromrtype,tra_fromcode,tra_fromcode_org,tra_totype,tra_tortype,tra_org)
               values
               (vTraCode,vDesc,'STTK','STTK',o7sess.cur_user,trl.trl_date,'A','A',
               'STOR','STOR','*','*',trl.trl_store,vOrg,'*','*',vOrg);

                insert into r5translines
                (trl_trans,trl_type,trl_rtype,trl_line,trl_date,trl_part,trl_part_org,
                trl_lot,trl_bin,trl_store,trl_price,trl_avgprice,trl_origqty,trl_qty,trl_io,
                trl_udfchar11,trl_udfchar12,trl_udfchar13,trl_udfchar14)
                values
                (vTraCode,'STTK','STTK',1,trl.trl_date,trl.trl_part,trl.trl_part_org,
                trl.trl_lot,trl.trl_bin,trl.trl_store,trl.trl_price,trl.trl_price,vFuelReceiptQty,vFuelReceiptQty,-1,
                trl.trl_udfchar11,trl.trl_udfchar12,trl.trl_udfchar13,vFlrCode
                );*/
                
             end if; --if vCnt = 0 then
                
         end if; --trl.trl_type = 'RECV'
         
         if trl.trl_type = 'RETN' then
            begin
              select dep_code into vDepCode
              from r5depots where dep_org = trl.trl_order_org and dep_udfchar01 = trl.trl_store
              and rownum <=1;
              update r5translines 
              set trl_udfchar11 = vDepCode
              where rowid=:rowid
              and   nvl(trl_udfchar11,' ')<> nvl(vDepCode,' ');
            exception when no_data_found then
              null;
            end;
			
			select count(1) into vCnt
            from r5tanks,r5fuels
            where tan_fuel = fue_code
            and   tan_depot = trl.trl_udfchar11 and tan_depot_org =  trl.trl_order_org
            and   tan_code =  trl.trl_udfchar12
            and   fue_code =  trl.trl_udfchar13
			and   fue_udfchar02 = trl.trl_part
            and   tan_notused = '-';
			if vCnt = 0 then
                iErrMsg := 'Please select valid Depot,Tank, Fuel for fuel part receipt.';
                raise valErr;
		    end if;
           
         end if; --trl.trl_type = 'RETN'
           
     end if; --if vParClass = 'FUEL'
  end if; -- trl.trl_part is not null


exception 
when valErr then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg) ; 
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5translines/Post Insert/40/'||substr(SQLERRM, 1, 500)) ; 
end;