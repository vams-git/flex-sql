declare 
  tra            r5transactions%rowtype;
  vOrg           r5transactions.tra_org%type;
  vParClass      r5parts.par_class%type;
  vTraStatus     r5transactions.tra_status%type;
  vCurrQty       r5tanks.tan_qty%type;
  vFinCode       r5fuelinventory.fin_code%type;
  vDesc          r5fuelinventory.Fin_Desc%type;
  vFiaCode       r5fuelinventoryadjustments.fia_code%type;
  
  vCnt           number;
  iErrMsg        varchar2(200);
  valErr         exception;
  
  cursor cur_trl is
  select * from r5translines
  where trl_trans = tra.tra_code;
  
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_type ='RETN' and tra.tra_status ='A' then
      for trl in cur_trl loop
         if trl.trl_part is not null and trl.trl_type in ('RETN') and trl.trl_order is not null  then
         select par_class into vParClass from r5parts where par_code = trl.trl_part and par_org = trl.trl_part_org;
         if vParClass IN ('FUEL','ADBLUE') then
            begin
              select tra_org,tra_status
              into vOrg,vTraStatus
              from r5transactions 
              where tra_code = trl.trl_trans
              and tra_fromentity ='STOR' and tra_status ='A'
              and tra_type ='RETN';
            exception when no_data_found then
              return;
            end; 
          
            select count(1) into vCnt
            from r5tanks,r5fuels
            where tan_fuel = fue_code
            and   tan_depot = trl.trl_udfchar11 and tan_depot_org = vOrg
            and   tan_code =  trl.trl_udfchar12
            and   fue_code =  trl.trl_udfchar13
            and   tan_notused = '-';
            if vCnt = 0 then
              iErrMsg := 'Please select valid Depot,Tank, Fuel for fuel part receipt.';
              raise valErr;
            end if;
            
            select count(1) into vCnt
            from r5fuelinventory where fin_depot_org = vOrg 
            and fin_depot = trl.trl_udfchar11
            and fin_rstatus not in ('A','C');
            if vCnt > 0 then
               iErrMsg := 'Please complete fuel inventory for depot ' || trl.trl_udfchar11 ||'.';
               raise valErr;
            end if;
            
            --validate current tank qty
            select tan.tan_qty into vCurrQty
            from r5tanks tan
            where tan.tan_depot = trl.trl_udfchar11 and tan_depot_org = vOrg
            and   tan.tan_code = trl.trl_udfchar12;
            if vCurrQty - nvl(trl.trl_origqty,trl.trl_qty) < 0 then
               iErrMsg := 'Fuel qty is less than return qty, please contact Adminstrator.';
               raise valErr;
            end if;
            
            
            select s5fuelinventory.nextval into vFinCode from dual;
            vDesc := 'From PO ' || trl.trl_order || '-Fuel Retn-' || trl.trl_trans;
             
            insert into r5fuelinventory
            (fin_code,fin_desc,fin_depot,fin_depot_org,fin_updateqty,fin_status,fin_rstatus,fin_date,
            fin_createdby,fin_created)
            values
            (vFinCode,vDesc,trl.trl_udfchar11,vOrg,'+','A','A',trl.trl_date,
            o7sess.cur_user,trl.trl_date);
            
              /*insert into r5fuelinventorytanks
            (fit_fuelinventory,fit_line,fit_tank,fit_expqty,fit_phyqty)
            values
            (vFinCode,1,trl.trl_udfchar12,vCurrQty,vCurrQty - nvl(trl.trl_origqty,trl.trl_qty));*/
            
            select s5fuelinventory.nextval into vFiaCode from dual;
            insert into r5fuelinventoryadjustments
            (fia_code,fia_fuelinventory,fia_depot,fia_depot_org,fia_tank,fia_qty,fia_date)
            values
            (vFiaCode,vFinCode,trl.trl_udfchar11,vOrg,trl.trl_udfchar12,nvl(trl.trl_origqty,trl.trl_qty)*-1,trl.trl_date);
            
            update r5fuelinventorytanks
            set fit_phyqty = vCurrQty - nvl(trl.trl_origqty,trl.trl_qty)
            where fit_fuelinventory = vFinCode
            and   fit_tank = trl.trl_udfchar12;
            
            update r5tanks tan
            set tan_qty = vCurrQty - nvl(trl.trl_origqty,trl.trl_qty)
            where tan.tan_depot = trl.trl_udfchar11 and tan.tan_depot_org = vOrg
            and   tan.Tan_Code = trl.trl_udfchar12;
            
            
            update r5translines
            set    trl_udfchar14 = vFinCode
            where  trl_trans = trl.trl_trans and trl_line = trl.trl_line
            and    nvl(trl_udfchar14,' ') <>  nvl(vFinCode,' ');
            
               
         end if; --if vParClass = 'FUEL'
      end if; -- trl.trl_part is not null
  
      end loop;
  end if; --end if tra_type
  
exception 
when valErr then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg) ; 
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5transactions/Post Insert/50/'||substr(SQLERRM, 1, 500)) ; 
end;