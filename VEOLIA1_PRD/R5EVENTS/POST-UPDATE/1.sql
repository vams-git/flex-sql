DECLARE
  evt           r5events%rowtype;
  
  vTimeDiff     number;
  vGroup        r5users.usr_group%type;
  vIsDateValid  r5organizationoptions.opa_desc%type;
  vBDValidStatus  r5organizationoptions.opa_desc%type;
  vCount        number;
  vCompleted    date;
  vStart        date;
  vUdfDate03    date;
  vUdfDate04    date;
  vLocale       r5organization.ORG_LOCALE%type;
  vNewStart     date;
  vNewRestoreDate  date;
  
  iErrMsg       varchar2(400);
  err_chk       exception;
BEGIN
  -- This flex is replace R5EVENTS Trigger U5PREUPDEVENTS
  -- select the current WO 
  select * into evt from r5events where rowid=:rowid; --='1005379173';--
  if evt.evt_type not in ('PPM','JOB') then 
     return;
  end if;
  
  --vTimeDiff := abs(sysdate - evt.evt_created) * 24 * 60 * 60;
  select usr_group into vGroup from r5users where usr_code = o7sess.cur_user;
  if vGroup in ('VNZ-NOP1','VNZ-NOP2') and evt.evt_status in ('50SO','51SO','55CA') then
     iErrMsg := 'You are not authorized to update work order when status is Sign Off or Cost Assigned.';
     raise err_chk;
  end if;
  
  --get Org locale
  select nvl(org_locale,' ') into vLocale 
  from r5organization
  where org_code = evt.evt_org;

  
  --Validate Cost Code
  if evt.evt_costcode like '%-600-%' then
     iErrMsg:='Stock WBS cannot be used for Work Order transactions.';
     raise err_chk;
  end if;
    
  --For QGC, When work order status is 50SO 51SO, ?Date Completed?(EVT_COMPLETED) is mandatory
  --Except QGC, When work order status is 50SO 51SO and ?Date Completed?(EVT_COMPLETED) is empty, system auto fill in current date time for ?Date Completed?(EVT_COMPLETED)
  vCompleted := evt.evt_completed;
  if evt.evt_status in ('50SO','51SO') and evt.evt_completed is null then
     /*if evt.evt_org in ('QGC') then
        iErrMsg:='Date Completed is Required. Please amend the records accordingly.';
        raise err_chk;
     else*/
        vCompleted := o7gttime(evt.evt_org);
        update r5events
        set evt_completed = nvl(vCompleted,evt_completed)
        where rowid =:rowid
        and nvl(evt_completed,to_date('1900-01-01','yyyy-mm-dd')) <> nvl(vCompleted,evt_completed);
     --end if;
  end if;
  --When work order status is '49MF' and ?Site Completion?(EVT_UDFDATE04) is empty, system auto fill in current date time for ?Site Completion?(EVT_UDFDATE04)
  vUdfDate04 := evt.evt_udfdate04;
  if evt.evt_status in ('49MF') and evt.evt_udfdate04 is null then
     vUdfDate04:= o7gttime(evt.evt_org);
     update r5events
     set evt_udfdate04 = nvl(vUdfDate04,evt_udfdate04)
     where rowid =:rowid
     and nvl(evt_udfdate04,to_date('1900-01-01','yyyy-mm-dd')) <> nvl(vUdfDate04,evt_udfdate04);
  end if;
  --When work order status is '65RP','50SO','51SO', 
  --if Restoration Date (EVT_UDFDATE03) is blank, then the Restoration Date will be set to Site Completion (evt_udfdate04) for NZ orgs or set to Complete Date (EVT_COMPLETED) for other org
  --if Start Date (EVT_START) is blank or later than Site Completion, then the Start Date will set to Date of Site Completion (evt_udfdate04) for NZ orgs or set to Complete Date (EVT_COMPLETED) for other org 
  if evt.evt_status in ('65RP','50SO','51SO') then
   if vLocale = 'NZ' then
      vNewStart := trunc(vUdfDate04);
      vNewRestoreDate := vUdfDate04;
   else
      vNewStart := trunc(vCompleted);
      vNewRestoreDate := vCompleted;
   end if;
  
     select
     decode(evt.evt_start,null,vNewStart,evt.evt_start),
     decode(evt.evt_udfdate03,null,vNewRestoreDate,evt.evt_udfdate03)
     into vStart,vUdfDate03
     from dual;
     if vStart > vUdfDate04 then
       vStart := vNewStart;
     end if;
     
    if nvl(evt.evt_start,to_date('1900-01-01','yyyy-mm-dd')) <> nvl(vStart,evt.evt_start) then   
    if nvl(vStart,evt.evt_start) > o7gttime(evt.evt_org)+1/48 then 
       iErrMsg:='Please note it is not possible to input date in the future for Site Completion or Complete Date. Please amend the records accordingly.';
       raise err_chk;
    end if;
  end if;
  
    update r5events
    set evt_start = nvl(vStart,evt_start),
        evt_udfdate03 = nvl(vUdfDate03,evt_udfdate03)
    where rowid =:rowid
    and (
        nvl(evt_start,to_date('1900-01-01','yyyy-mm-dd')) <> nvl(vStart,evt_start) or
        nvl(evt_udfdate03,to_date('1900-01-01','yyyy-mm-dd')) <> nvl(vUdfDate03,evt_udfdate03)
        );
  end if;
  
 
  
  
  --manual work order validate datetime input
  if evt.evt_type in ('JOB') then
       --evt_reported,evt_completed,evt_udfdate01,evt_udfdate02,evt_udfdate03 cannot be futuer date
       if (evt.evt_reported  > o7gttime(evt.evt_org)+1/48)--Reported Time
       or (evt.evt_completed > o7gttime(evt.evt_org)+1/48)--Date Competed
       or (evt.evt_udfdate01 > o7gttime(evt.evt_org)+1/48)--Response By
       or (evt.evt_udfdate02 > o7gttime(evt.evt_org)+1/48)--First Repair Date
       or (evt.evt_udfdate03 > o7gttime(evt.evt_org)+1/48)--Restoration Date
      then
         iErrMsg:='Please note it is not possible to input date in the future. Please amend the records accordingly.';
         raise err_chk;
      end if;
      
      --Validation date by org option DATEVALD
      begin
        select opa_desc into vIsDateValid
        from r5organizationoptions WHERE OPA_CODE='DATEVALD' AND OPA_ORG =evt.evt_org;
      exception when no_data_found then
        vIsDateValid :='NO';
      end;
      if vIsDateValid = 'YES' then
        if evt.evt_status in ('48MR', '49MF','50SO','51SO','55CA','65RP','C') then
           if evt.evt_udfdate01 < evt.evt_reported then
             iErrMsg:='The Response By cannot be earlier than the Failure Time. Please amend the records accordingly.';
             raise err_chk;
           end if;
           If evt.evt_udfdate02 < evt.evt_udfdate01 then
              iErrMsg:='The First Repair Date cannot be earlier than the Response By. Please amend the records accordingly.';
              raise err_chk;
           end if;
           if vUdfDate03 < evt.evt_udfdate02 then
              iErrMsg:='The Restoration Date cannot be earlier than the First Repair Date. Please amend the records accordingly.';
              raise err_chk;
           end if;
           if vUdfDate04 < vUdfDate03 then
              iErrMsg:='The Site Completion cannot be earlier than the Restoration Date. Please amend the records accordingly.';
              raise err_chk;
           end if;
           --??? double check activity date validation on work order flex????????
           select count(1) into vCount from r5activities
           where act_event = evt.evt_code
           and   act_udfdate04 < act_udfdate03;
           if vCount > 0 then
              iErrMsg:='The Service Restored/Back On time cannot be earlier than the Service Interrupted/Off time. Please amend the records accordingly.';
              raise err_chk;
           end if;
        end if;--if if status
      end if; --if if IsDateValid
      
      --evt_reported and evt_udfdate03 are mandatory when status is BD and status in vBDValidStatus org option
      begin
        select opa_desc into vBDValidStatus
        from r5organizationoptions WHERE OPA_CODE='BDWOVALD' AND OPA_ORG =evt.evt_org;
      exception when no_data_found then
        vBDValidStatus := 'NO';
      end;
    if vBDValidStatus != 'NO' then
      if INSTR(vBDValidStatus,evt.evt_status) != 0 and evt.evt_class in ('BD','CO') and evt.evt_parent is null then
       if evt.evt_reported is null or evt.evt_udfdate03 is null then
          iErrMsg:='Please input the equipment Failure Time and equipment Restoration / Time Work Completed';
          raise err_chk;
       end if;
       if evt.evt_udfdate03 < evt.evt_reported then
          iErrMsg:='The Restoration Date cannot be earlier than the Failure Time. Please amend the records accordingly.';
          raise err_chk;
       end if;
       if evt.evt_completed < evt.evt_reported then
          iErrMsg:='The Date Completed cannot be earlier than the Failure Time. Please amend the records accordingly.';
          raise err_chk;
       end if;
       if evt.evt_completed < evt.evt_udfdate03 then
          iErrMsg:='The Date Completed cannot be earlier than the Restoration Time. Please amend the records accordingly.';
          raise err_chk;
       end if;
      end if;
    end if;
    
  end if;
  


EXCEPTION
WHEN err_chk THEN
  RAISE_APPLICATION_ERROR ( -20003, iErrMsg);
/*WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/1/'||substr(SQLERRM, 1, 500));*/
END;
