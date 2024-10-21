declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  vNewStatus    r5invoices.inv_status%type;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  
  rql           r5requislines%rowtype;
  vReqLine      r5requislines.rql_reqline%type;
  vRqlEvt       r5requislines.rql_event%type;
  vRqlAct       r5requislines.rql_act%type;
  vRqlDue       r5requislines.rql_due%type;
  
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'PU01' then
     begin
       update r5orderlines
       set orl_status = tkd.tkd_promptdata5
       where orl_order_org = tkd.tkd_promptdata1
       and   orl_order = tkd.tkd_promptdata2
       and   orl_ordline = tkd.tkd_promptdata3;
     
     exception when err_val then
        RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
     end;
         
     --delete from r5trackingdata where rowid=:rowid;
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  
  if tkd.tkd_trans = 'PU02' then
     begin
          select * into rql from r5requislines where rql_req = tkd.tkd_promptdata2 and rql_reqline = tkd.tkd_promptdata3;
          if rql.rql_event is not null then
             --add activity
             select max(act_act) +  10 into vRqlAct
             from r5activities
             where act_event = rql.rql_event;
             insert into r5activities
             (act_event,act_act,act_supplier,act_supplier_org,act_ordtype,act_hire,act_ordrtype,act_planninglevel,
              act_mrc,act_trade,act_start,act_time,act_persons,act_duration,act_est,act_rem,act_note)--,act_req act_reqline     
             select 
             act_event,vRqlAct,act_supplier,act_supplier_org,act_ordtype,act_hire,act_ordrtype,act_planninglevel,
             act_mrc,act_trade,trunc(o7gttime(tkd.tkd_promptdata1)),act_time,act_persons,act_duration,act_est,act_est,act_note
             from r5activities
             where act_event = rql.rql_event and act_act = rql.rql_act;
             vRqlEvt := rql.rql_event;
          else
             vRqlEvt := null;
             vRqlAct := null;
          end if;
          
          if rql.rql_due < trunc(o7gttime(tkd.tkd_promptdata1)) then
             vRqlDue := trunc(o7gttime(tkd.tkd_promptdata1));
          else
             vRqlDue := rql.rql_due;
          end if;
          
          select max(rql_reqline) +  10 into vReqLine
          from r5requislines where rql_req = tkd.tkd_promptdata2;
          insert into r5requislines
          (rql_req,rql_reqline,rql_part,rql_part_org,rql_udfchar27,rql_due,rql_type,rql_active,rql_status,rql_rstatus,rql_quotflag,rql_scrapqty,rql_inspect,
           rql_supplier,rql_supplier_org,rql_deladdress,rql_costcode,rql_curr,rql_exch,
           rql_event,rql_act,rql_trade,rql_task,rql_taskrev,rql_taskqty,
           rql_price,rql_qty,rql_uom,rql_multiply,             
           rql_udfchar01,rql_udfchar02,rql_udfchar20,rql_udfchar26,rql_udfnum01,rql_udfnum02,rql_udfnum03)
          select 
           rql_req,vReqLine,rql_part,rql_part_org,rql_udfchar27,vRqlDue,rql_type,rql_active,rql_status,rql_rstatus,rql_quotflag,rql_scrapqty,rql_inspect,
           rql_supplier,rql_supplier_org,rql_deladdress,rql_costcode,rql_curr,rql_exch,
           vRqlEvt,vRqlAct,rql_trade,rql_task,rql_taskrev,rql_taskqty,
           rql_price,rql_qty,rql_uom,rql_multiply,             
           rql_udfchar01,rql_udfchar02,rql_udfchar20,rql_udfchar26,rql_udfnum01,rql_udfnum02,rql_udfnum03
           from r5requislines 
           where rql_req = tkd.tkd_promptdata2 and rql_reqline = tkd.tkd_promptdata3;
           
           if rql.rql_event is not null then
              update r5activities
              set act_req =  tkd.tkd_promptdata2,act_reqline = vReqLine
              where act_event = rql.rql_event and act_act = vRqlAct;
           end if;
            
          
     exception when err_val then
        RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
     end;
     --delete from r5trackingdata where rowid=:rowid;
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  
exception
  when no_data_found then 
    null;
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/110/' ||SQLCODE || SQLERRM) ;
end;
