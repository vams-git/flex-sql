declare
  ucd           u5vucosd%rowtype;
  vCnt          number;
  vRcnt         number;
  iErrMsg       varchar2(200);
  errval        exception;
  
  cursor cur_osr is 
  select * from u5oustcr where osr_status = 'WOUDF' and osr_refreshed = '+';
  --and osr_sessionid = 37241837;
  
  cursor cur_wocnt(vObj varchar2,vOrg varchar2,vLocation varchar2,vMRC varchar2,vCstCode varchar2) is 
  select count(distinct evt_Code) as evt_openwocnt
  from r5objects,r5events
  where obj_code = evt_object and obj_org = evt_object_org
  and   evt_rstatus <> 'C'
  and   (nvl(obj_udfchar01,' ') <> nvl(evt_udfchar01,' ') or nvl(obj_udfchar02,' ') <> nvl(evt_udfchar02,' ') 
     or  nvl(obj_udfchar03,' ') <> nvl(evt_udfchar03,' ') or nvl(obj_udfchar04,' ') <> nvl(evt_udfchar04,' ') 
     or  nvl(obj_udfchar05,' ') <> nvl(evt_udfchar05,' ') or nvl(obj_udfchar06,' ') <> nvl(evt_udfchar06,' ') 
     or  nvl(obj_udfchar07,' ') <> nvl(evt_udfchar07,' ') or nvl(obj_udfchar08,' ') <> nvl(evt_udfchar08,' ') 
     or  nvl(obj_udfchar09,' ') <> nvl(evt_udfchar09,' ') or nvl(obj_udfchar10,' ') <> nvl(evt_udfchar10,' ') 
     or  nvl(obj_udfchar11,' ') <> nvl(evt_udfchar11,' ') or nvl(obj_udfchar12,' ') <> nvl(evt_udfchar12,' ') 
     or  nvl(obj_udfchar13,' ') <> nvl(evt_udfchar13,' ') or nvl(obj_udfchar14,' ') <> nvl(evt_udfchar14,' ') 
     or  nvl(obj_location,' ')  <> decode(vLocation,'+',nvl(evt_location,' '), nvl(obj_location,' '))
     or  nvl(obj_mrc,' ')  <> decode(vMRC,'+',nvl(evt_mrc,' '), nvl(obj_mrc,' '))
     or  nvl(obj_costcode,' ')  <> decode(vCstCode,'+',nvl(evt_costcode,' '), nvl(obj_costcode,' '))
  )
  and obj_code||'#'||obj_org in 
  (select stc_child ||'#'|| stc_child_org
  from r5structures
  connect by  prior stc_child = stc_parent AND prior stc_child_org = stc_parent_org
  start with stc_parent = vObj
  and stc_parent_org = vOrg
  );
  
  cursor cur_wo(vObj varchar2,vOrg varchar2,vLocation varchar2,vMRC varchar2,vCstCode varchar2) is 
  select evt_code,evt_object,evt_object_org
  ,obj_udfchar01,obj_udfchar02,obj_udfchar03,obj_udfchar04,obj_udfchar05,obj_udfchar06,obj_udfchar07
  ,obj_udfchar08,obj_udfchar09,obj_udfchar10,obj_udfchar11,obj_udfchar12,obj_udfchar13,obj_udfchar14
  ,obj_location,obj_location_org,obj_mrc,obj_costcode
  from r5objects,r5events
  where obj_code = evt_object and obj_org = evt_object_org
  and   evt_rstatus <> 'C'
  and   (nvl(obj_udfchar01,' ') <> nvl(evt_udfchar01,' ') or nvl(obj_udfchar02,' ') <> nvl(evt_udfchar02,' ') 
     or  nvl(obj_udfchar03,' ') <> nvl(evt_udfchar03,' ') or nvl(obj_udfchar04,' ') <> nvl(evt_udfchar04,' ') 
     or  nvl(obj_udfchar05,' ') <> nvl(evt_udfchar05,' ') or nvl(obj_udfchar06,' ') <> nvl(evt_udfchar06,' ') 
     or  nvl(obj_udfchar07,' ') <> nvl(evt_udfchar07,' ') or nvl(obj_udfchar08,' ') <> nvl(evt_udfchar08,' ') 
     or  nvl(obj_udfchar09,' ') <> nvl(evt_udfchar09,' ') or nvl(obj_udfchar10,' ') <> nvl(evt_udfchar10,' ') 
     or  nvl(obj_udfchar11,' ') <> nvl(evt_udfchar11,' ') or nvl(obj_udfchar12,' ') <> nvl(evt_udfchar12,' ') 
     or  nvl(obj_udfchar13,' ') <> nvl(evt_udfchar13,' ') or nvl(obj_udfchar14,' ') <> nvl(evt_udfchar14,' ') 
     or  nvl(obj_location,' ')  <> decode(vLocation,'+',nvl(evt_location,' '), nvl(obj_location,' '))
     or  nvl(obj_mrc,' ')  <> decode(vMRC,'+',nvl(evt_mrc,' '), nvl(obj_mrc,' '))
     or  nvl(obj_costcode,' ')  <> decode(vCstCode,'+',nvl(evt_costcode,' '), nvl(obj_costcode,' '))
  )
  and obj_code||'#'||obj_org in 
  (select stc_child ||'#'|| stc_child_org
  from r5structures
  connect by  prior stc_child = stc_parent AND prior stc_child_org = stc_parent_org
  start with stc_parent = vObj
  and stc_parent_org = vOrg
  ) and rownum<=1000;

  
begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 9 and ucd.ucd_recalccost = '+' then
  for rec_osr in cur_osr loop
    
      if rec_osr.osr_openwo is null then
        for rec_wocnt in cur_wocnt(rec_osr.osr_object,rec_osr.osr_org,rec_osr.osr_isrloc,rec_osr.osr_isrmrc,rec_osr.osr_isrcst) loop
            vRcnt := rec_wocnt.evt_openwocnt;
            update u5oustcr
            set    osr_openwo = vRcnt
            where  osr_sessionid =rec_osr.osr_sessionid;
        end loop;
      end if;
      
      begin 
         for rec_wo in cur_wo(rec_osr.osr_object,rec_osr.osr_org,rec_osr.osr_isrloc,rec_osr.osr_isrmrc,rec_osr.osr_isrcst) loop
             begin
               update r5events set
               evt_udfchar01 = rec_wo.obj_udfchar01,
               evt_udfchar02 = rec_wo.obj_udfchar02,
               evt_udfchar03 = rec_wo.obj_udfchar03,
               evt_udfchar04 = rec_wo.obj_udfchar04,
               evt_udfchar05 = rec_wo.obj_udfchar05,
               evt_udfchar06 = rec_wo.obj_udfchar06,
               evt_udfchar07 = rec_wo.obj_udfchar07,
               evt_udfchar08 = rec_wo.obj_udfchar08,
               evt_udfchar09 = rec_wo.obj_udfchar09,
               evt_udfchar10 = rec_wo.obj_udfchar10,
               evt_udfchar11 = rec_wo.obj_udfchar11,
               evt_udfchar12 = rec_wo.obj_udfchar12,
               evt_udfchar13 = rec_wo.obj_udfchar13,
               evt_udfchar14 = rec_wo.obj_udfchar14,
               evt_location = decode(rec_osr.osr_isrloc,'+',rec_wo.obj_location,evt_location),
               evt_location_org = decode(rec_osr.osr_isrloc,'+',rec_wo.obj_location_org,evt_location_org),
               evt_mrc = decode(rec_osr.osr_isrmrc,'+',rec_wo.obj_mrc,evt_mrc),
               evt_costcode = decode(rec_osr.osr_isrcst,'+',rec_wo.obj_costcode,evt_costcode)
               where evt_code = rec_wo.evt_code;
               
               
             exception when others then 
               null;
             end;
         end loop;
         
         update u5oustcr
         set    osr_message = to_char(vRcnt)||'#WOs UDF to be updated!'
         where  osr_sessionid =rec_osr.osr_sessionid;
      exception when others then
         update u5oustcr
         set    osr_status = 'Failed', osr_message = 'Fail to update WO UDF! '
         where  osr_sessionid =rec_osr.osr_sessionid;
      end;
      
      for rec_wocnt in cur_wocnt(rec_osr.osr_object,rec_osr.osr_org,rec_osr.osr_isrloc,rec_osr.osr_isrmrc,rec_osr.osr_isrcst) loop
          if rec_wocnt.evt_openwocnt = 0 then
             update u5oustcr
             set    osr_status ='COMPLETED',osr_worefreshed = '+',osr_message = 'WO UDF are updated successfully!'
             where  osr_sessionid = rec_osr.osr_sessionid;
          end if;
      end loop;
  end loop;
  
  update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;

exception when others then
  null;
end;
