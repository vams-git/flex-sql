declare 
  evt               r5events%rowtype; 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  vCount            number;
 
begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
    IF evt.evt_org in ('WBP') and evt.evt_status IN ('55CA') THEN
        select count(1) into vCount
        from r5events,r5contactrecords ctr
        where evt_code = ctr_event and evt_org = ctr_event_org
        and ctr_udfchar08 is not null and ctr_udfchar01 in ('Reactive','Planned','Instructed')
        and nvl(evt_udfchar24,' ') not in ('INVO','INVP','PAID')
        and  evt_code = evt.evt_code;
        if vCount > 0 then
          iErrMsg := 'This workorder is unable to move to Cost Assigned as it has not been validated by the Client';
          raise err_chk;
        end if;
      END IF;
  end if; 
  
EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/240/'||substr(SQLERRM, 1, 500)) ;
end;