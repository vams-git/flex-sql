declare 
  ucd   u5vucosd%rowtype;
  cursor evo is
  select evo_event from u5vucost where  evo_recalccost = '+'; 
  recs NUMBER := 0;
  
  PROCEDURE calc(event VARCHAR2) IS
    vOrg varchar2(15); vParent varchar2(30); vChildCnt number:=0; event_rt varchar2(30); vSplitNo number:=0;
    intlabhr number:=0; colabhr number:=0; polabhr number:=0; extlabhr number:=0; labhr number:=0;
    sownlab number:=0; colab number:=0; intlab number:=0;
    shiredlab number:=0;shiredlabinv number:=0;shiredlabord number:=0; 
    ssvrlab number:=0;ssvrlabinv number:=0;ssvrlabord number:=0;
    svr number:=0;svr_rt number:=0;svr_ord number:=0;
    spdmat number:=0; spdmatinv number:=0; spdmatord number:=0; pdmat number:=0; pdmat_rt number:=0; pdmat_ord number:=0;
    sstkmat number:=0; stkmat number:=0;
    stool number:=0; toolmat number:=0; tool number:=0;
    total number:=0; total_rt number:=0;
    d varchar2(1);vMsg varchar2(255);
  BEGIN
   begin  
   select evt_org,evt_parent into vOrg,vParent from r5events where evt_code = event;
   exception when no_data_found then
     delete from u5vucost where evo_event = event;
   end;
   select count(1) into vChildCnt from r5events where evt_parent = event;
      
   select
   nvl(round(sum(case when per_mrc not like '%-CO' then nvl(nvl(boo_orighours,boo_hours),0) end),2),0), 
   nvl(round(sum(case when per_mrc like '%-CO' then nvl(nvl(boo_orighours,boo_hours),0) end),2),0),
   nvl(round(sum(case when per_mrc like '%-CO' then nvl(nvl(boo_orighours,boo_hours)*boo_rate,0) end),2),0)
   into intlabhr,colabhr,colab
   from r5bookedhours,r5personnel where boo_person = per_code and boo_event = event;
   select nvl(sum(nvl(boo_orighours,boo_hours)),0) into polabhr  
   from (select  act_event,boo_orighours,boo_hours,
   decode(b.boo_routeparent,null,nvl(b.boo_order,act.act_order),bp.boo_order) as boo_order,
   decode(b.boo_routeparent,null,nvl(b.boo_ordline,act.act_ordline),bp.boo_ordline) as boo_ordline,
   decode(b.boo_routeparent,null,nvl(b.boo_order_org,act.act_order_org),bp.boo_order_org) as boo_order_org
   from  r5activities act,r5bookedhours b left join (select boo_code,
   nvl(boo_order,act_order) as boo_order,nvl(boo_ordline,act_ordline) as boo_ordline,nvl(boo_order_org,act_order_org) as boo_order_org
   from r5activities,r5bookedhours where act_event = boo_event and act_act = boo_act) bp on b.boo_routeparent = bp.boo_code where act_event = b.boo_event and act_act= b.boo_act
   and b.boo_person is null and b.boo_event > 0 and b.boo_act >0) left join r5orderlines on orl_order=boo_order and orl_ordline=boo_ordline and orl_order_org = boo_order_org
   where orl_type like 'S%'and orl_puruom = 'h.' and act_event  = event;

   select nvl(round(sum(nvl((nvl(trl_origqty,trl_qty) * trl_price * (case when trl_type ='RETN' then 1 else decode(trl_io,0,-1,trl_io) end) *-1),0)),2),0)
   into   toolmat
   from   r5transactions,r5translines,r5parts
   where  tra_code = trl_trans and par_code=trl_part and par_org=trl_part_org and par_tool is not null and tra_status ='A' and trl_io <>0 and trl_event = event;

   /* Get actual cost for own labour */
   o7actlab('EVT',event,null,null,null,sownlab,d);
   /* Get actual cost for  hired labour */
   o7acthir('EVT',event,null,null,null,shiredlab,d);
   o7pidhir('EVT',event,null,null,null,shiredlabinv,d);
   o7remhir('EVT',event,null,null,null,shiredlabord,d);
   /* Get actual cost for fixed price services */
   o7actfix('EVT',event,null,null,null,ssvrlab,d);
   o7pidfix('EVT',event,null,null,null,ssvrlabinv,d);
   o7remfix('EVT',event,null,null,null,ssvrlabord,d);
   /* Get actual cost for stock material */
   o7actmat('EVT',event,null,null,null,sstkmat,d);
   /* Get actual cost for direct material */
   o7actdma('EVT',event,null,null,null,spdmat,d);
   begin
   o7piddma('EVT',event,null,null,null,spdmatinv,d);
   exception when others then
     spdmatinv := 0;
   end;
   o7remdma('EVT',event,null,null,null,spdmatord,d);
   /* Get actual cost for tool cost */
   o7acttool('EVT',event,null,null,null,stool,d);

 
   extlabhr:=colabhr+polabhr;
   labhr:=intlabhr+extlabhr;

   intlab := nvl(sownlab,0)-colab;
   svr := nvl(shiredlab,0) + nvl(ssvrlab,0) + nvl(colab,0) + nvl(shiredlabinv,0) + nvl(ssvrlabinv,0);
   svr_ord := nvl(shiredlabord,0) + nvl(ssvrlabord,0);
   stkmat := nvl(sstkmat,0) - nvl(toolmat,0);
   pdmat := nvl(spdmat,0)+ nvl(spdmatinv,0);
   pdmat_ord := nvl(spdmatord,0);
   tool := nvl(stool,0) + nvl(toolmat,0);
   total := intlab + svr + stkmat + pdmat + tool;
        

    if vParent is not null then
       event_rt := vParent;
    else 
       event_rt := event;
    end if;
    
    select nvl(sum(case when nvl(boo_udfnum05,0) = 0 then nvl(boo_orighours,boo_hours)*boo_rate else boo_udfnum05 end 
    ),0) into svr_rt
    from r5events,r5bookedhours
    where evt_code = boo_event and boo_person is null 
    and ((boo_misc ='-') or (boo_misc ='+' and boo_ocrtype in ('O','X')))
    and   evt_code = event_rt;
    svr_rt := nvl(svr_rt,2) + nvl(colab,0);

    select nvl(sum(case when nvl(trl_udfnum05,0) = 0 then nvl(trl_origqty,trl_qty)*trl_price else trl_udfnum05 end 
    * decode(trl_type,'RECV',1,-1)),0) into pdmat_rt
    from r5events,r5transactions,r5translines
    where evt_code = trl_event
    and   trl_trans = tra_code and tra_status ='A'
    and   trl_type in ('RECV','RETN') and trl_order is not null and trl_io = 0 
    and   evt_code = event_rt;
    
    
    if vParent is not null then
        SELECT count(*) into vSplitNo
        FROM   r5events
        WHERE  evt_routeparent = vParent;
        if vSplitNo > 0 then
           svr_rt := round(svr_rt/vSplitNo,2);
           pdmat_rt := round(pdmat_rt/vSplitNo,2);
        end if;
    end if;

    total_rt := intlab + svr_rt + stkmat + pdmat_rt + tool;

   update u5vucost set 
   evo_org = vOrg,evo_parent = vParent,evo_childcnt = vChildCnt,
   evo_intboohours = intlabhr,evo_hiredboohours = extlabhr,evo_labourhours = labhr,
   evo_intboocost = intlab, evo_servicecost = svr, evo_partcost = stkmat, evo_partpdcost = pdmat, evo_toolcost =tool,
   evo_totalcost = total,
   evo_servicecost_rt = svr_rt,evo_partpdcost_rt = pdmat_rt,evo_totalcost_rt = total_rt,
   evo_servicecost_ord = svr_ord,evo_partpdcost_ord = pdmat_ord,
   evo_recalccost = '-',evo_costcalculated = '+',evo_error ='-',evo_updated = sysdate
   where evo_event = event;
   --update r5eventcost set evo_recalccost = '-',evo_costcalculated = '+' where evo_event = event;
  exception when others then 
    --vMsg := substr(SQLERRM, 1, 255);
    update u5vucost set evo_error = '+',evo_errormsg = vMsg,evo_updated = sysdate where evo_event = event;   
  END calc;
 
  
begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 1 and ucd.ucd_recalccost = '+' then
    recs := 0;
  for i IN evo loop
      recs := recs + 1;
      calc( i.evo_event );
      IF recs > 100000 THEN
          RETURN;
      END IF;
  end loop;
  update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;

end;
