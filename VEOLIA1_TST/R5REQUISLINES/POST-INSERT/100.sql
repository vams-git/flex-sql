declare 
  rql      r5requislines%rowtype;
  vLocale  r5organization.org_locale%type;
  vOrg     r5organization.org_code%type;
  vStatus  r5events.evt_status%type;
  iErrMsg  varchar2(400);
  err_val  exception;
  
begin
  -- If local is NZ, then requisition cannot be created from status 55CA
  -- If org is TAS or VIS, then requisition cannot be created from status 55CA
  -- if local is not NZ, and is org is not TAS/VIS, then  requisition cannot be created from status 50SO, 51SO and 55CA 
  select * into rql from r5requislines rql where rql.rowid=:rowid;
  if rql.rql_event is not null then
     select org_code,NVL(org_locale,'AUS'),evt_status
     into   vOrg,vLocale,vStatus
     from   r5events evt,r5organization org
     where  evt.evt_org = org.org_code
     and    evt_code = rql.rql_event;
     if (vLocale ='NZ' or vOrg in ('TAS','VIC','WAU','WAR','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP')) and vStatus in ('55CA') then
        iErrMsg := 'Cannot create requisition due to work order is Cost Assigned.';
        raise err_val;
     end if;
     if (vLocale not in ('NZ') and vOrg not in ('TAS','VIC','WAU','WAR','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP')) and vStatus in ('50SO','51SO','55CA') then
       iErrMsg := 'Cannot create requisition due to work order is Sign Off or Cost Assigned.';
       raise err_val;
     end if;
  end if;
  
exception 
  when err_val then
    RAISE_APPLICATION_ERROR (-20003, 'ERR/R5REQUISLINES/100/I - '||iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5REQUISLINES/100/I - ') ;
end;