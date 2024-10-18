declare 
  osr      u5oustcr%rowtype;
  vObjCnt  number;
begin
  --updateO
  select * into osr from u5oustcr where rowid=:rowid;
  
  select
  count(distinct stc_child) into vObjCnt
  from r5structures stc
  connect by  prior stc_child = stc_parent AND prior stc_child_org = stc_parent_org
  start with stc_parent = osr.osr_object and stc_parent_org = osr.osr_org
  order by stc_childtype;
  
  update u5oustcr
  set    osr_childcnt = vObjCnt,osr_refreshed ='-',osr_openwo = null,osr_worefreshed = '-',osr_status = 'DRAFT',osr_message = null
  where  rowid=:rowid;
exception when others then  
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex u5oustcr/Post Insert/10/'||substr(SQLERRM, 1, 500)) ; 
end;