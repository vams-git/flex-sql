declare 
  tra                r5transactions%rowtype;
  vCount             number;
  
  vReceiptTrans      r5translines.trl_trans%type;
  vReceiptTransLine  r5translines.trl_line%type;
  vReceiptDate       r5translines.trl_date%type;
  vInvQty            r5translines.trl_udfnum04%type;
  
  iErrMsg            varchar2(500);
  err_validate       exception;
  
  cursor cur_trl(vTraCode varchar2) is 
  select * from r5translines
  where trl_trans = vTraCode;
begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_status ='A' and tra.tra_type ='RETN' and tra.tra_routeparent is null then
    for rec_trl in cur_trl(tra.tra_code) loop
       begin
          --Validate return qty and receipt qty by transaction
          select trl_trans,trl_line,trl_date into vReceiptTrans,vReceiptTransLine,vReceiptDate from
          (select trl_trans,trl_line,trl_date
          from r5transactions,r5translines
          where tra_code = trl_trans and tra_routeparent is null
          and tra_type ='RECV'
          and trl_order = rec_trl.trl_order and trl_ordline = rec_trl.trl_ordline
          --and nvl(trl_origqty,trl_qty) - nvl(trl_udfnum04,0) = nvl(rec_trl.trl_origqty,rec_trl.trl_qty)
          and nvl(trl_origqty,trl_qty) = nvl(rec_trl.trl_origqty,rec_trl.trl_qty)
          and trl_udfchar26 is null
          order by trl_trans desc
          )where rownum <= 1;
          
          
          select nvl(trl_udfnum04,0) into vInvQty
          from r5translines
          where trl_trans = vReceiptTrans
          and   trl_line = vReceiptTransLine;
          if vInvQty <> 0 then
             iErrMsg := 'Return Qty. must be same as Receipt Transaction Qty for Part '|| rec_trl.trl_part ||'. And Receipt line Qty must not be invoiced.';
             raise err_validate;
          end if;
          

          --Update Return code on Receipt Line
          update r5translines
          set    trl_udfchar26 = rec_trl.trl_trans,trl_udfchar25 = rec_trl.trl_line
          where  trl_trans = vReceiptTrans and trl_line = vReceiptTransLine
          and    (nvl(trl_udfchar26,' ') <> rec_trl.trl_trans or nvl(trl_udfchar25,' ')<> rec_trl.trl_line);
          
           --Upldate Receipt Code on Return Line
          update r5translines
          set    trl_udfchar26 = vReceiptTrans,
                 trl_udfchar25 = vReceiptTransLine,
                 trl_udfdate05 = vReceiptDate
          where  trl_trans = rec_trl.trl_trans and trl_line = rec_trl.trl_line
          and    (nvl(trl_udfchar26,' ') <> vReceiptTrans or nvl(trl_udfchar25,' ')<> vReceiptTransLine or trl_udfdate05<>vReceiptDate);
          
        exception when no_data_found then
          iErrMsg := 'Return Qty. must be same as Receipt Transaction Qty for Part '|| rec_trl.trl_part ||'. And Receipt line Qty must not be invoiced.';
          raise err_validate;
        end;
    end loop;
  end if;
    
  
  
exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Update/210') ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;
