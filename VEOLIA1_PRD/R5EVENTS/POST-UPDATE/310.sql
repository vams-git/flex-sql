--Check evt_reported is filled for Parent WO?
DECLARE
    icount        number;
    rec_event     r5events%rowtype;
    
    db_err        exception;
    iLang         r5users.usr_lang%type;
    iErrMsg       varchar2(500);
BEGIN
   select * into rec_event from r5events where rowid=:rowid; 
    
   if (rec_event.evt_type not in ('JOB','PPM')) then return; end if;
   
   if rec_event.evt_reported is null then
      select count(1) into icount 
      from r5events 
      where evt_parent = rec_event.evt_code and evt_jobtype='MEC'; 
      if icount > 0 then
        raise db_err;
      end if;
   end if;
   
exception
when db_err then
    iErrMsg:= 'Failure time is mandatory for Parent Work Order!';
    RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
END;