declare 
  ccr               R5CONTACTRECORDS%rowtype; 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  vCount            number;

begin
  
  select * into ccr from R5CONTACTRECORDS where rowid=:rowid;
  if ccr.CTR_ORG in ('WSL','THC','WAN','STA','RUA','DOC')  
  and ccr.CTR_STATUS IN ('O') then
    if ccr.CTR_UDFNUM04 is null or ccr.CTR_UDFNUM05 is null then
        iErrMsg := 'Address must be selected via ArcGIS API. Please use the lookup button provided';
        raise err_chk;
    end if;
  end if;

EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex r5contactrecords/Post Insert/40/'||substr(SQLERRM, 1, 500)) ;
end;