declare 
  evt               r5events%rowtype; 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  vCount            number;

begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM')  
  and evt.evt_org in ('ALC') and evt.evt_status IN ('40PR') then
    if evt.evt_udfchar28 is null then
       iErrMsg := 'Client Ref No. is mandatory when work order change to Preapred';
       raise err_chk;
    end if;
  end if; 
  
EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/240/'||substr(SQLERRM, 1, 500)) ;
end;