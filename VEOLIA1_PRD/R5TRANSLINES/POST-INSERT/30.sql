declare 
     rec_trl     r5translines%rowtype;
     
     vOrg        r5organization.org_code%type;
     vCnt        number;
     
     v_IssueQty  r5translines.trl_qty%type;
     
     iErrMsg     varchar2(500);
     DB_ERROR1   exception;
     val_err     exception;
     
     vIssTrans   r5translines.trl_trans%type;
     vRecvTrans  r5translines.trl_trans%type;
begin
     select * into rec_trl from r5translines where rowid=:rowid;
     if rec_trl.trl_event is not null and rec_trl.trl_type = 'MISC' and rec_trl.trl_qty < 0 then
        select evt_org into vOrg from r5events where evt_code = rec_trl.trl_event;
        if vOrg in ('WSL','QTN','WEW','RUA','STA','THC','CHB','DAN','DOC','SWP','VEO','WAN') then
           select count(1) into vCnt from r5translines
           where trl_event = rec_trl.trl_event and trl_act = rec_trl.trl_act
           and   trl_type =  rec_trl.trl_type 
           and   trl_desc = rec_trl.trl_desc and abs(trl_qty * trl_price) = abs(rec_trl.trl_qty * rec_trl.trl_price)
           and   trl_trans <> rec_trl.trl_trans;
           if vCnt = 0 then 
              iErrMsg := 'Additonal Cost Correction description and value must be same as Receipt Transaction.';
              raise val_err;
           end if;
        end if;
     end if;
     
     if rec_trl.trl_event is not null and rec_trl.trl_type = 'I' and rec_trl.trl_qty < 0 then
        select nvl(sum(trl_qty),0)
        into   v_IssueQty
        from   r5translines
        where  trl_event =rec_trl.trl_event 
        and    trl_act = rec_trl.trl_act
        and    trl_part = rec_trl.trl_part
        and    trl_store = rec_trl.trl_store
        and    trl_type  ='I'
        and    rowid<>:rowid;
        if (rec_trl.trl_qty  * -1) > v_IssueQty then
          iErrMsg := 'Cannot return part quantity more than issue Qty.';
          raise val_err;
        end if;
     end if;
     
     --validate is bin transfer
     begin
       select biniss.trl_trans,binrecv.trl_trans
       into   vIssTrans,vRecvTrans
       from r5translines biniss,r5translines binrecv
       where biniss.trl_part = binrecv.trl_part and biniss.trl_part_org =binrecv.trl_part_org
       and   biniss.trl_type = 'I' and binrecv.trl_type='RECV'
       and   biniss.trl_store = binrecv.trl_store and biniss.trl_lot =binrecv.trl_lot 
       and   biniss.trl_bin <> binrecv.trl_bin
       and   biniss.trl_price = binrecv.trl_price and  biniss.trl_qty = binrecv.trl_qty
       and   binrecv.trl_trans-biniss.trl_trans =1 
       and   (binrecv.trl_trans = rec_trl.trl_trans or biniss.trl_trans =  rec_trl.trl_trans);
       
       update r5translines
       set    trl_udfchkbox05 ='+'
       where  trl_trans = vIssTrans 
       and    trl_udfchkbox05 = '-';
       
       update r5translines
       set    trl_udfchkbox05 ='+'
       where  trl_trans = vRecvTrans 
       and    trl_udfchkbox05 = '-'; 
     exception when no_data_found then
        null;
     end;
     
     
exception 
  when val_err then  
    RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
end;