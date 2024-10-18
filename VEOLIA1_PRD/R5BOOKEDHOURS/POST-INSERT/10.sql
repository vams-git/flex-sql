declare
 devtcompleted date;
 devtstart     date;
 evtorg       r5organization.org_code%type;
 evtstatus    r5events.evt_status%type;
 v_datevald   nvarchar2(10);
 row_boo      r5bookedhours%rowtype;
 
 DB_ERROR1    EXCEPTION;
 DB_ERROR2    EXCEPTION;
 iErrMsg      varchar2(400); 
 iLang        r5users.usr_lang%type; 
begin
 select * into row_boo
 from r5bookedhours where rowid=:rowid;
 
 if row_boo.boo_event is not null then
   select nvl(evt_completed,TO_DATE( NULL )),nvl(evt_start,TO_DATE( NULL )),evt_org,evt_status
   into devtcompleted ,devtstart,evtorg,evtstatus
   from r5events where evt_code = row_boo.boo_event;
   /*BOO_DATE must be less than r5events.EVT_COMPLETED*/
   if (row_boo.boo_date > trunc(devtcompleted)) then
     RAISE DB_ERROR1;
   end if;
   
   
   if evtstatus = '40PR' then
     begin
       select opa_desc into v_datevald
       from r5organizationoptions WHERE OPA_CODE='WAUTOSIP' AND OPA_ORG =evtorg;
     exception when no_data_found then
        v_datevald :='NO';
     end;
     if v_datevald = 'YES' THEN
       update r5events
       set evt_status ='41IP'
       where evt_code =  row_boo.boo_event;
      end if;
   end if;
   /*BOO_DATE must be later than r5events.EVT_START*/
   /*
   begin
   select opa_desc into v_datevald
   from r5organizationoptions WHERE OPA_CODE='DATEVALD' AND OPA_ORG =evtorg;
   exception when no_data_found then
      v_datevald :='NO';
   end;
   if v_datevald = 'YES' and (row_boo.boo_date < trunc(devtstart)) then
     RAISE DB_ERROR2;
   end if;*/
 end if;

exception 
  when DB_ERROR1 then
  --select usr_lang into iLang from r5users where usr_code = o7sess.cur_user;
  iErrMsg := 'The WO reporting Date in the Record View is earlier than the Date Worked for  Labour/Services. 
              Please either adjust the Labour/Service Date Worked, or modify the WO Date Completed ' || to_char(devtcompleted,'DD-MON-YYYY');  
  RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when DB_ERROR2 then
  iErrMsg := 'Please note the Date Worked entered is earlier than the Start Date/Respond By value. Please adjust the Date Worked, or modify the Start Date/Respond By accordingly.';  
  RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
end;
