declare 
  bis             r5binstock%rowtype;
  trl             r5translines%rowtype;
  
  vStrGrp         r5stores.str_pricecode%type;
  vStockSrcType   r5stores.str_udfchar01%type;
  vDestStore      r5stores.str_code%type;
  vDestStoreOrg   r5stores.str_org%type;
  vSrcStore       r5stores.str_code%type;
  vSrcStoreOrg    r5stores.str_org%type;
  vParTool        r5parts.par_tool%type;

   vTrlTrans        r5translines.trl_trans%type;
   vTrlLine         r5translines.trl_line%type;
   vTrlStore        r5translines.trl_store%type;
   vPart            r5parts.par_code%type;
   vPartOrg         r5parts.par_org%type;
   vBin             r5bins.bin_code%type;
   vLot             r5lots.lot_code%type;
   vPrice           r5translines.trl_price%type;
   vTransQty        r5translines.trl_qty%type;
   vIO              r5translines.trl_io%type;
   vWO              r5events.evt_code%type;
   vTrlUpdated      r5translines.trl_updated%type;
   
   trancode         r5transactions.tra_code%type;
   vDesc            r5transactions.tra_desc%type;
  
  vCurUser         varchar2(30);
  vLocTimeTime     date;
  vUtcTime         date;
  iErrMsg          varchar2(500);
  err_validate     exception;
  chk              varchar2(3);
  vCnt             number;
  
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
    else
       vIO := -1;
       vTrlStore := vSrcStore;
    end if;
     
    insert into r5translines
    (trl_trans,trl_type,trl_rtype,trl_line,trl_date,trl_part,trl_part_org,
     trl_lot,trl_bin,trl_store, trl_price,trl_avgprice,trl_qty,trl_io,
     trl_udfchar26,
     trl_created, trl_lastsaved)
     values
    (trancode,vTransType,vTransType,1,vLocTimeTime,vPart,vPartOrg,
     vLot,vBin,vTrlStore,vPrice,vPrice,vTransQty,vIO,
     vTrlTrans,
     vUtcTime,vUtcTime);
END;
  
begin
   select * into bis from r5binstock where rowid=:rowid;
   if bis.bis_qty > 0 then
       select par_tool into vParTool
     from r5parts
     where par_code = bis.bis_part and par_org = bis.bis_part_org;
     if vParTool is not null then
        return;
     end if;
     
       select str.str_pricecode,str.str_udfchar01,str_code,str_org
       into   vStrGrp,vStockSrcType,vSrcStore,vSrcStoreOrg
       from   r5stores str
       where  str.str_code = bis.bis_store;

               
       if vStockSrcType like 'STOREGRP%' then
           begin
             select str_code,str_org
             into   vDestStore,vDestStoreOrg
             from   r5stores str
             where  str.str_pricecode = vStrGrp
             and    nvl(str_udfchkbox01,'-') = '+';
             --and    str.str_code <> vSrcStore;
            exception when no_data_found then
              iErrMsg:= 'Matching store is not found in System!';
              raise err_validate;
            when others then
              iErrMsg:= 'Matching store is not found in System!';
              raise err_validate;
            end;
            if vDestStore is null then
               iErrMsg:= 'Matching store is not found in System!';
               raise err_validate;
            end if;
       end if; -- vIsFromCenStr = '+'

       
       vTrlTrans := null;
       begin
         --get last return transaction\
         select sts_trans,sts_line, lastsaved 
         into vTrlTrans,vTrlLine,vTrlUpdated
         from (
         select sts_trans,sts_line,sts.lastsaved
         from U5TUSTSL sts
         where sts_org = vSrcStoreOrg and sts_store =  bis.bis_store
         and sts_part = bis.bis_part and sts_part_org = bis.bis_part_org
         and   sts_io = -1 and sts_qty < 0
         and   abs(sysdate - sts.lastsaved) * 24 * 60 * 60 < 2
         order by lastsaved desc
         ) where rownum<=1;

       exception when no_data_found then
          RETURN;
       end;
              
       if vTrlTrans is  not null then
           select count(1) into vCnt from 
           r5translines
           where trl_store = bis.bis_store and trl_part = bis.bis_part and trl_part_org = bis.bis_part_org
           and   nvl(trl_udfchar26,' ') = vTrlTrans;
           if vCnt = 0 then
               select * into trl from r5translines where trl_trans = vTrlTrans and trl_line = vTrlLine;
               
               vWO := trl.trl_event;
               vCurUser := nvl(o7sess.cur_user,'R5');
               vUtcTime := sysdate;
               vDesc := substr('Transfer for Reserved (Return) part ' || trl.trl_part || ' for WO ' || trl.trl_event,1,80);
                          
               vBin := trl.trl_bin;
               vLot := trl.trl_lot;
               vPart := trl.trl_part;
               vPartOrg := trl.trl_part_org;
               vTransQty := abs(nvl(trl.trl_origqty,trl.trl_qty));
                          
               vPrice := o7getprc(vSrcStore,vPart,vPartOrg,vSrcStoreOrg,'A',null,null);
               --Insert Issue Sourcestore org
               vLocTimeTime := o7gttime(vSrcStoreOrg);
               insert_transactions(vSrcStoreOrg,'I');
               --Insert receive dest org
               vLocTimeTime := o7gttime(vDestStoreOrg);
               insert_transactions(vDestStoreOrg,'RECV');
           end if; -- vCnt = 0 
        end if;--vTrlTrans is  not */
       
   end if; --bis.bis_qty > 0
   
exception 
  when err_validate then
       RAISE_APPLICATION_ERROR (-20001,iErrMsg);
  when others then
       RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex r5binstock/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;