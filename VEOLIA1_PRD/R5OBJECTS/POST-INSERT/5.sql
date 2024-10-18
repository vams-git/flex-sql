declare
   obj           r5objects%rowtype;
   vExistObj     varchar2(200);
   vSeq          r5ecmaxseq.ecx_sequence%type;
   vCnt          number;
   maxseq        number;
   iErrMsg       varchar2(400);
   err           exception;
   
   
begin
    select * into obj from r5objects where rowid=:rowid;
    if obj.obj_udfchar40 is not null then
      begin
        select obj_code||'('||obj_org||')' into vExistObj
        from r5objects 
        where  nvl(obj_udfchar40,'x') = nvl(obj.obj_udfchar40,'x')
        and    nvl(obj_udfchar38,'x') = nvl(obj.obj_udfchar38,'x')
        and    obj_status <> 'TRD'
        and    obj_code <> obj.obj_code
        and    rowid<>:rowid
        and    rownum<=1;
        iErrMsg := 'SAP Fixed Asset Number is found in VAMS on Asset '|| vExistObj;
        raise err;
      exception 
      when no_data_found then
        null;
      end;
      
      if o7sess.cur_user IN ('MIGRATION','DATABRIDGEINTERNALUSER','ASSET.MANAGEMENT@VEOLIA.COM') then
         insert into U5IUFXOB
         (ifa_org,ifa_plant,ifa_sapasset,ifa_obtype,ifa_create,ifa_status, 
          createdby,created,updatecount)
         values
         (obj.obj_org,obj.obj_udfchar38,obj.obj_code,obj.obj_obtype,o7gttime(obj.obj_org),'New',
          o7sess.cur_user,o7gttime(obj.obj_org),0);
      end if;
    end if;

exception 
  when err then 
      RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Insert/5/'||SQLCODE || SQLERRM) ; 
end;