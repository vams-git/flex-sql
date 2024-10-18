declare 
evt             r5events%rowtype;
vLocale         r5organization.org_locale%type;
vCount          number;  
vNewValue       r5audvalues.ava_to%type;
vOldValue       r5audvalues.ava_from%type;
vNewUDFCHAR24   r5audvalues.ava_to%type;
vOldUDFCHAR24   r5audvalues.ava_from%type;
vIsUpdUDFCHAR24 varchar2(1);
vNewUDFCHAR20   r5audvalues.ava_to%type;
vOldUDFCHAR20   r5audvalues.ava_from%type;
vIsUpdUDFCHAR20 varchar2(1);
vAuthOrg        r5organization.org_code%type;
vTimeDiff       number;
vActUDate04     r5activities.act_udfdate04%type;
vGroup          r5users.usr_group%type;
val_err         exception;
iErrMsg         varchar2(200);

vOpenPOVal_Orgs varchar2(4000);
     
begin
    select * into evt from r5events where rowid=:rowid;
    if evt.evt_type in ('JOB','PPM') then
       vOpenPOVal_Orgs := 'TAS, NWA, WAU, WAR, SAU, NTE, QLD, NSW, VIC, NVP, NVW, NVE';
       select org_locale into vLocale from r5organization where org_code = evt.evt_org;
     
       if vLocale in ('NZ') or instr(vOpenPOVal_Orgs,evt.evt_org) > 0 then
          begin
              select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
              from (
              select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
              from r5audvalues,r5audattribs
              where ava_table = aat_table and ava_attribute = aat_code
              and   aat_table = 'R5EVENTS' and aat_column in ('EVT_STATUS')
              and   ava_table = 'R5EVENTS' 
              and   ava_primaryid = evt.evt_code
              and   ava_updated = '+'
              --and ava_inserted ='+'
              and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
              order by ava_changed desc
              ) where rownum <= 1;
              
           exception when no_data_found then 
              vNewValue := null;
           end;
       
           if vLocale in ('NZ') then
             --allow user groups VNZ-NOP1 an VNZ-NOP2 to be able to change WO status from 41IP "In progress" to "49MF "Mobile Finished" only when WO class is equal to PS
             if vNewValue is not null and evt.evt_status = '49MF' and vOldValue = '41IP' then 
              select usr_group into vGroup from r5users where usr_code = o7sess.cur_user;
                if vGroup in ('VNZ-NOP1','VNZ-NOP2') and evt.evt_class <> 'PS' then
                 iErrMsg := 'You are only authorized to change status to Mobile Fininshed for PS class work orders.';
                 raise val_err;
                end if;
             end if;
           end if;
       
           if  vLocale in ('NZ') or instr(vOpenPOVal_Orgs,evt.evt_org) > 0 then
             if evt.evt_status in ('55CA','C') and vNewValue is not null then
               SELECT COUNT(1) into vCount
               FROM   R5ORDERS,R5ORDERLINES
               WHERE  ORD_CODE = ORL_ORDER
               AND    ORL_EVENT = evt.evt_code
               AND    ORD_STATUS NOT IN ('RC','RI','CP','C','CAN');
               if vCount > 0 then
                iErrMsg := 'The WorkOrder can not be changed to Cost Assigned with open Purchase Order.';
                raise val_err;
               end if; --vCount > 0 
             end if; --evt.evt_status in ('55CA','C') and vNewValue is not null 
           end if; --instr(vOpenPOVal_Orgs,evt.evt_org) > 0 
       end if;
     
       if vLocale in ('NZ') then
           --WO with EVT_UDFCHAR20 (Recovery Code) equals to "A" or "R", 
           --values in field EVT_UDFCHAR24 (Financial Status) cannot be changed to "INVP" unless there is at least one line in the new tab/UDS
          if  evt.evt_parent is null and evt.evt_udfchar20 in ('A','R') and evt.evt_udfchar24 in ('INVP') then
              select count(1) into vCount
              from u5wucinv 
              where wui_org = evt.evt_org and wui_event = evt.evt_code;
              if vCount = 0 then
                iErrMsg := 'This Work Order requires an Customer invoice to move to the next step.';
                raise val_err;
              end if;
          end if;
          
          --Excepted Event Approved?(EVT_UDFCHKBOX01) only can be ticked when Excepted Event Sought?'EVT_UDFCHKBOX02) is ticked
          if evt.evt_udfchkbox01='+' and evt.evt_udfchkbox02='-' then
              iErrMsg := 'The excepted event cannot be approved as it hasn''t been sought yet. Please amend the record accordingly.';
              raise val_err;
          end if;

          --iErrMsg := 'timediff:' || to_char(vTimeDiff);
          --raise val_err;
          --WO Status cannot be changed to 48MR if ACT_TASK  is empty.
          if evt.evt_status in ('48MR') AND
            ((evt.evt_class in ('BD','CO') and evt.evt_org not in ('WCC','ACW','WEW'))
              or (evt.evt_class in ('BD','CO','RN','PS') and evt.evt_org in ('WBP'))
             )
           then
            select count(1) into vCount
            from r5activities
            where act_event = evt.evt_code
            and   act_task is not null;
            --iErrMsg := 'vCount:' || to_char(vCount);
            if  vCount = 0 then
               iErrMsg := 'The Work Order status cannot be changed to Mobile Awaiting Reinstatement without task assigned.';
               raise val_err;
            end if;
          end if;
            
           --WO Status can be changed to ?Mobile dispatched? if evt_person is null
          if evt.evt_status ='43MD' and evt.evt_person is null then
              iErrMsg := 'Work Order cannot be dispatched with an employee assigned to it.';
              raise val_err;
          end if;
            
          --evt_reported mandatory for all NZ orgs except WCC,ACW when WO class equals BD or CO and when WO status is changed to status 43MD, 49MF, and 50SO
          if evt.evt_org not in ('WCC','ACW','WEW') and
            evt.evt_status in ('43MD','49MF','50SO','51SO') and evt.evt_class in ('BD','CO')  then
            if evt.evt_reported is null then
               iErrMsg := 'Please note capture of the equipment failure time.';
               raise val_err;
            end if;
          end if;
            
          --if  TSK_UDFCHKBOX05 from the WO Activity Task ACT_TASK = true, then the WO status cannot be changed to 49MF if EVT_UDFDATE04 and EVT_UDFDATE01 are empty
          if evt.evt_status='49MF' then
            select count(1) into vCount
            from   r5activities,r5tasks
            where  act_task = tsk_code and act_taskrev = tsk_revision
            and    act_event = evt.evt_code
            and    tsk_udfchkbox05='+'
            and    (act_udfdate03 is null or act_udfdate04 is null );
            if  vCount > 0 then
                iErrMsg := 'This Work Order cannot be finished without Service Restored/Back On time and Service Interrupted/Off time.';
                raise val_err;
            end if;
          end if;
            
           
           
           begin
              select ava_to,ava_from,timediff into vNewUDFCHAR24,vOldUDFCHAR24,vTimeDiff
              from (
              select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
              from r5audvalues,r5audattribs
              where ava_table = aat_table and ava_attribute = aat_code
              and   aat_table = 'R5EVENTS' and aat_column in ('EVT_UDFCHAR24')
              and   ava_table = 'R5EVENTS' 
              and   ava_primaryid = evt.evt_code
              and   ava_updated = '+'
              --and ava_inserted ='+'
              and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
              order by ava_changed desc
              ) where rownum <= 1;
              vIsUpdUDFCHAR24 := 'Y';
           exception when no_data_found then 
              vIsUpdUDFCHAR24 := 'N';
           end;
           begin
              select ava_to,ava_from,timediff into vNewUDFCHAR20,vOldUDFCHAR20,vTimeDiff
              from (
              select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
              from r5audvalues,r5audattribs
              where ava_table = aat_table and ava_attribute = aat_code
              and   aat_table = 'R5EVENTS' and aat_column in ('EVT_UDFCHAR20')
              and   ava_table = 'R5EVENTS' 
              and   ava_primaryid = evt.evt_code
              and   ava_updated = '+'
              --and ava_inserted ='+'
              and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
              order by ava_changed desc
              ) where rownum <= 1;
              vIsUpdUDFCHAR20 := 'Y';
           exception when no_data_found then 
              vIsUpdUDFCHAR20 := 'N';
           end;
           

            IF vIsUpdUDFCHAR24 ='N' AND EVT.EVT_UDFCHAR24 IN ('NON','CLAIMV','INVP','PAID' ) THEN
              IF vIsUpdUDFCHAR20 = 'Y' THEN
                iErrMsg := 'Cannot change Recovery Code due to Financial Status.';
                raise val_err;
              END IF;
            END IF;
            
            IF EVT.EVT_UDFCHAR20 IS NULL AND EVT.EVT_UDFCHAR24 IS NOT NULL THEN
                iErrMsg := 'Financial Status cannot be recorded, because Recovery Code is blank.';
                raise val_err;
            END IF;
            IF EVT.EVT_UDFCHAR20 IN ('U','P','R','A') AND EVT.EVT_UDFCHAR24 IN ('NON') THEN
                iErrMsg := 'Wrong Financial Status, because Recovery Code is U/P/R/A. Please select another Financial Status.';
                raise val_err;
            END IF;
            IF EVT.EVT_UDFCHAR20 IN ('L','I') AND EVT.EVT_UDFCHAR24 NOT IN ('NON') THEN
                iErrMsg := 'Wrong Financial Status, because Recovery Code is L/I. Please enter another Financial Status.';
                raise val_err;
            END IF;


            IF EVT.EVT_STATUS ='C' THEN
               IF EVT.EVT_UDFCHAR20 IS NULL OR EVT.EVT_UDFCHAR24 IS NULL THEN
                 iErrMsg := 'The WO cannot be Completed, because Recovery Code and Financial Status are NOT filled.';
                 raise val_err;
               END IF;
               IF EVT.EVT_UDFCHAR24 NOT IN ('NON','PAID') THEN
                 iErrMsg := 'The WO cannot be Completed, because Financial Status is not Non-Invoiceable Or Paid.';
                 raise val_err;
               END IF;
            END IF;
            
            IF vIsUpdUDFCHAR24 = 'Y' THEN
              SELECT COUNT(1) into vCount FROM U5FUAUTH WHERE NUA_ENTITY = 'EVNT' AND NUA_FIELD = 'EVT_UDFCHAR24' AND NUA_ORG = EVT.EVT_ORG;
              IF vCount > 0 THEN
                 vAuthOrg := EVT.EVT_ORG;
              else
                 vAuthOrg := '*';
              end if;
              SELECT COUNT(1) INTO vCount FROM U5FUAUTH
              WHERE NUA_ENTITY = 'EVNT' AND NUA_FIELD = 'EVT_UDFCHAR24'
              AND   NUA_ORG = vAuthOrg
              AND   NUA_VALUE = NVL(vOldUDFCHAR24,'-')
              AND   NUA_VALUENEW = NVL(vNewUDFCHAR24,'-');
              IF  vCount = 0 THEN
                  iErrMsg := 'Financial Status could not be changed to this status.';
                  raise val_err;
              END IF;
          END IF;
          
          --When WO Status is changed to ?Mobile Started? , fill WorkOrder\STARTDATE
          if evt.evt_status ='46MS' and evt.evt_udfdate01 is null then
             update r5events 
             set evt_udfdate01 = o7gttime(evt.evt_org)
             where evt_code = evt.evt_code;
          end if;

          if evt.evt_status in ('47MR','48MR') and evt.evt_udfdate03 is null then
             update r5events 
             set evt_udfdate03 = o7gttime(evt.evt_org)
             where evt_code = evt.evt_code;
          end if;
          
          --When a WO status is changed to 49MF, if evt_udfdate02 is empty, the value from EVT_UDFDATE04 is copied to evt_udfdate02
          if evt.evt_status='49MF' and evt.evt_udfdate02 is null then
            begin
              select act_udfdate04 into vActUDate04 from r5activities where act_event =evt.evt_code and rownum <=1 ;
              if vActUDate04 is not null then
              update r5events 
              set evt_udfdate02 = vActUDate04
              where evt_code = evt.evt_code;
              end if;
            exception when no_data_found then
              null;
            end;
          end if;

          
       end if; -- vLocale in ('NZ')
    end if; --('JOB','PPM')
   
     
      
exception 
when no_data_found then
     return;  
WHEN val_err THEN 
    RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;    
end;
