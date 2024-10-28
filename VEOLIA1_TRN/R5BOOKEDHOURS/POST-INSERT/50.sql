declare
 boo             r5bookedhours%rowtype;
 vBookHours      r5bookedhours.boo_hours%type;
 vCorrBookHours  r5bookedhours.boo_hours%type;
 
 vOrg            r5organization.org_code%type;
 vBookCode       r5bookedhours.boo_code%type;
 vObjCode        r5objects.obj_code%type;
 vSpiltRef       r5bookedhours.boo_udfchar04%type;
 
 vOverlapCnt     number;
 vCnt            number;
 val_err         EXCEPTION;
 iErrMsg         varchar2(400); 
begin
 select * into boo from r5bookedhours where rowid=:rowid;
 
 if boo.boo_person is not null and boo.boo_correction = '+' then
   /*select NVL(sum(abs(nvl(BOO_ORIGHOURS,BOO_HOURS))),0) into vBookHours
   from R5BOOKEDHOURS 
   where BOO_EVENT = boo.boo_event and BOO_ACT = boo.boo_act
   and   BOO_PERSON = boo.boo_person 
   and   BOO_DATE = boo.boo_date 
   and   BOO_OCTYPE = boo.boo_octype 
   and   BOO_CORRECTION<>'+';
   
   select NVL(sum(abs(nvl(BOO_ORIGHOURS,BOO_HOURS))),0)  into vCorrBookHours
   from R5BOOKEDHOURS 
   where BOO_EVENT = boo.boo_event and BOO_ACT = boo.boo_act
   and   BOO_PERSON = boo.boo_person 
   and   BOO_DATE = boo.boo_date 
   and   BOO_OCTYPE = boo.boo_octype 
   and   BOO_CORRECTION = '+';
   
   if vCorrBookHours > vBookHours then
      iErrMsg := 'You may not correct more hours than have been booked for the employee on the specified Date Worked and Type of hours; enter another value.'; 
      raise val_err;
   end if;*/
   
   if boo.boo_octype ='OD' and boo.boo_udfchar02 is null then
      --Correction Hours for OD should be same as book hours
      --Get last OD book hours for WO
        begin
          /*select evt_org,boo_code,evt_object,boo_hours
          into vOrg,vBookCode,vObjCode,vBookHours from
          (select evt_org,boo_code,evt_object,nvl(boo_orighours,boo_hours) as boo_hours
          from r5bookedhours,r5events
          where boo_event = evt_code
          and   BOO_EVENT = boo.boo_event and BOO_ACT = boo.boo_act
          and   BOO_PERSON = boo.boo_person 
          and   BOO_DATE = boo.boo_date 
          and   BOO_OCTYPE = boo.boo_octype
          and   nvl(boo_orighours,boo_hours) > 0
          and   nvl(boo_orighours,boo_hours) = abs(boo.boo_hours)
          and   (boo_udfchar02 is null or boo_udfchar02 like 'Err%') 
          order by boo_acd desc
          )where rownum <= 1;*/
          
          select evt_org,evt_object
          into vOrg,vObjCode
          from r5events
          where evt_code = boo.boo_event;
          
          
          vSpiltRef := substr(('Corr:'|| '/' ||vOrg || '/' || vObjCode || '/' || to_char(o7gttime(vOrg),'DD-MM-YYYY HH24:MI')),1,80);
          
          update r5bookedhours set boo_udfchar02 = boo.boo_correction_ref,boo_udfchar04 = vSpiltRef where boo_code = boo.boo_code;
          update r5bookedhours set boo_udfchar02 = boo.boo_code,boo_udfchar04 = vSpiltRef where boo_Code = boo.boo_correction_ref;
        exception when no_data_found then
          iErrMsg := 'On Demand Correction hours must be same as Book hours; enter another value.';
          raise val_err;
        end;
   end if;
 end if;
 
 --Validate overlap booking for temporary fix the Incident
 --boo_udfchar02 is updated by flex r5objects/25/spiltod hours or correction on OD hours
 if  boo.boo_person is not null and boo.boo_correction = '-' and boo.boo_octype ='OD' and boo.boo_on is not null and boo.boo_udfchar02 is null then
     select count(1) into vOverlapCnt from r5bookedhours where boo_person = boo.boo_person 
     and trunc(boo_date) = trunc(boo.boo_date) and boo_on < boo.boo_off and boo_off > boo.boo_on
     and boo_octype = 'OD' and boo_correction ='-' and boo_correction_ref is null --nvl(boo_udfchar04,' ') not like 'Corr%'
     and boo_code <> boo.boo_code;
     if vOverlapCnt > 0 then
        iErrMsg := 'This employee has already been assigned to other On Demand work on this date during the time frame specified.  Overlap of actual labor time entries is not permitted.';
        raise val_err;
     end if;
 end if;
 
 --Validation Boo_On and Boo_Off for Orgs
 
 if boo.boo_person is not null and boo.boo_correction = '-' and (boo.boo_on is null or boo.boo_off is null) then
    select evt_org into vOrg from r5events where evt_code = boo.boo_event;
    if vOrg in ('BPK','SYN','ALC','PKM','WAU','WAR','NWA') then
       iErrMsg := 'Please enter Start time and End time.';
       raise val_err;
    end if;        
 end if;
 
 --tick boo_udfchkbox03 if the corrected is against by booked hours TRANSACTION
 if boo.boo_person is not null and boo.boo_correction = '+' and  boo.boo_correction_ref is not null then
    select nvl(boo_orighours,boo_hours) into vBookHours from r5bookedhours where boo_code =  boo.boo_correction_ref;   
  if abs(vBookHours) = abs(nvl(boo.boo_orighours,boo.boo_hours)) then
     update r5bookedhours set boo_udfchkbox03 = '+' where boo_code = boo.boo_code;
     update r5bookedhours set boo_udfchkbox03 = '+' where boo_code = boo.boo_correction_ref;
  end if;
 end if;
 
 --Validate return hours and description must be same as initial transaction in additioal cost tab
 if boo.boo_person is null and boo.boo_misc = '+' and boo.boo_hours < 0 then 
    select evt_org into vOrg from r5events where evt_code = boo.boo_event;
    if vOrg in ('WSL','QTN','WEW','RUA','STA','THC','CHB','DAN','DOC','SWP','VEO','WAN') then
       select count(1) into vCnt from r5bookedhours
       where boo_event = boo.boo_event and boo_act = boo.boo_act
       and   boo_misc =  boo.boo_misc and boo_octype = boo.boo_octype
       and   boo_desc = boo.boo_desc and abs(boo_hours * boo_cost) = abs(boo.boo_hours * boo.boo_cost)
       and   boo_code <> boo.boo_code;
       if vCnt = 0 then 
          iErrMsg := 'Additonal Cost Correction description and value must be same as Receipt Transaction.';
          raise val_err;
       end if;
    end if;
 end if;

exception 
  when val_err then  
    RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
end;
