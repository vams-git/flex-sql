declare 
  ucd         u5vucosd%rowtype;
  vMaintCost  u5ourcst.orc_maintcost%type;
  vCapCost    u5ourcst.orc_capcost%type;
  vOthCost    u5ourcst.orc_othcost%type;
  vFuelCost   u5ourcst.orc_fuelcost%type;
  vDepcost    u5ourcst.orc_depcost%type;
  cursor cur1 is select * from u5ourcst orc where orc.orc_recalccost ='+';

begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 3 and ucd.ucd_recalccost = '+' then
    for r in cur1 loop
      begin
          select 
          round(sum(case when evt_Class in ('CO','BD','PS') then boo_cost - boo_invdiff else 0 end),2) as obj_maintcost,
          round(sum(case when evt_Class in ('RF','RN','CN','MO')  then boo_cost - boo_invdiff else 0 end),2) as obj_capitalcost,
          round(sum(case when evt_Class not in ('CO','BD','PS','RF','RN','CN','MO') then boo_cost - boo_invdiff else 0 end),2) as obj_othercost
          into vMaintCost,vCapCost,vOthCost
          from (
          select
          boo_code, 
          evt_class,
          nvl(case when nvl(boo_udfnum05,0) = 0 then nvl(boo_orighours,boo_hours)*boo_rate else boo_udfnum05 end 
          --* decode(boo_correction,'+',-1,1)
          ,0) as boo_cost,
          0 as boo_invdiff
          from r5objects,r5eventobjects,r5events,r5bookedhours
          where obj_code = eob_object(+) and obj_org = eob_object_org(+)
          and   evt_code = eob_event
          and   evt_code = boo_event
          and   evt_type in ('JOB','PPM')
          and   evt_status <>'30CL'
          and   boo_routeparent is null
          and   obj_obtype = '05FP' and obj_org = r.orc_org and obj_code = r.orc_object
          and   trunc(boo_date)>= r.orc_startdate and trunc(boo_date)<=r.orc_enddate

          union 
          select 
          to_char(trl_trans||trl_line) as trl_trans,
          evt_class,
          nvl(
          case when trl_type in ('RECV','RETN') then 
            case when nvl(trl_udfnum05,0) = 0 then nvl(trl_origqty,trl_qty)*trl_price else trl_udfnum05 end * decode(trl_type,'RECV',1,-1) 
          when trl_type in ('MISC') then nvl(trl_origqty,trl_qty)*trl_price
          else nvl(trl_origqty,trl_qty)*trl_price * trl_io * -1 end,0) as trl_cost,
          0 as trl_invdiff

          from r5objects,r5eventobjects,r5events,r5translines,r5transactions tra
          where obj_code = eob_object(+) and obj_org = eob_object_org(+)
          and   evt_code = eob_event
          and   evt_code = trl_event
          and   trl_trans = tra_code
          and   evt_type in ('JOB','PPM')
          and   evt_status <>'30CL'
          and   tra_status ='A'
          and   tra.tra_routeparent is null 
          and   obj_obtype = '05FP' and obj_org = r.orc_org and obj_code = r.orc_object
          and   trunc(trl_date)>= r.orc_startdate and trunc(trl_date)<=r.orc_enddate

          union 
            
          select 
          to_char(tou_acd) as tou_acd,
          evt_class,
          nvl(tou_cost,0) as tou_cost
          ,0 as tou_invdiff
          from r5objects,r5eventobjects, r5events,r5toolusage
          where obj_code = eob_object(+) and obj_org = eob_object_org(+)
          and   evt_code = eob_event
          and   evt_code = tou_event
          and   evt_type in ('JOB','PPM')
          and   evt_status <>'30CL'
          and   obj_obtype = '05FP' and obj_org = r.orc_org and obj_code = r.orc_object
          and   trunc(tou_dateused)>= r.orc_startdate and trunc(tou_dateused)<=r.orc_enddate
          );

         --get fuel cost
         select round(sum(nvl(fli_qty * fli_price,0)),2) into vFuelCost
         from  r5fuelissues fli,r5objects,r5structures stc
         where fli.fli_vehicle = obj_code and fli_vehicle_org = obj_org
         and   obj_code = stc_child and obj_org = stc_child_org
         and   stc.stc_parent_org = r.orc_org and stc.stc_parent = r.orc_object
         and   stc.stc_parenttype ='05FP'
         and   trunc(fli_date) >= r.orc_startdate and trunc(fli_date) <= r.orc_enddate;
         
         --get dep cost
         select round(sum(osd_depvalue),2) into vDepcost
         from u5ousdep,r5objects,r5structures stc
         where osd_object = obj_code and osd_object_org = obj_org
         and   obj_code = stc_child and obj_org = stc_child_org
         and   stc.stc_parent_org = r.orc_org and stc.stc_parent = r.orc_object
         and   stc.stc_parenttype ='05FP'
         and   trunc(osd_date) >= r.orc_startdate and trunc(osd_date) <= r.orc_enddate;
   
         
         update u5ourcst orc
         set orc.orc_maintcost = nvl(vMaintCost,0),
         orc.orc_capcost = nvl(vCapCost,0),
         orc.orc_othcost = nvl(vOthCost,0),
         orc.orc_fuelcost = nvl(vFuelCost,0),
         orc.orc_depcost = nvl(vDepcost,0),
         orc.orc_costcalculated ='+',
         orc.orc_recalccost = '-',
		 orc.orc_lastupddated = sysdate
         where orc.orc_org = r.orc_org and orc.orc_object = r.orc_object
         and   orc.orc_uom = r.orc_uom
         and   orc.orc_reagroup = r.orc_reagroup;
      exception when others then 
         null;
      end;
    end loop;
  update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;
  
end;