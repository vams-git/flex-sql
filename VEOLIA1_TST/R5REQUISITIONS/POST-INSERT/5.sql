declare 
 req              r5requisitions%rowtype;
 vOrgUdf09        r5organization.org_udfchar09%type;
 iErrMsg          varchar2(400);
 val_err          exception;
 
begin
  select * into req from r5requisitions where rowid=:rowid;
  select org_udfchar09 into vOrgUdf09
  from   r5organization where org_code = req.req_org;
  
  if req.req_fromcode not like nvl(vOrgUdf09,'CAUS-'||req.req_org)||'%' then
    iErrMsg := 'Please select supplier for ' || vOrgUdf09;
    raise val_err;
  end if;

    

exception 
  when val_err then 
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Insert/5/'||SQLCODE || SQLERRM) ;
end;
 