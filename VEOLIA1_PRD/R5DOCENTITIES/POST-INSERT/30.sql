declare 
  dae           r5docentities%rowtype;
  vOrg          r5organization.org_code%type;  
  vDocFileName  r5documents.doc_filename%type;
  vCnt          number;
begin
   select * into dae from r5docentities 
   where rowid=:rowid;
    --dae_code = '1005875885' and dae.dae_printonwo = '413935';
    
   if dae.dae_entity='EVNT' and dae.dae_printonwo = '-' then
      select count(1) into vCnt 
      from r5docentities d
      where d.dae_document = dae.dae_document
      and   d.dae_entity <> 'EVNT' and d.dae_copytowo ='+';
      if vCnt > 0 then 
         return;     
      end if;
    

      select evt_org into vOrg
      from r5events
      where evt_code = dae.dae_code;
      if vOrg in ('BPK', 'MMO', 'ALC', 'SYN', 'PKM','HWC') then
         select doc_filename
         into   vDocFileName--count (1) into vcnt
         from   r5documents doc
         where  doc_code = dae.dae_document;
         
         if upper(vDocFileName) like '%.JPG' or upper(vDocFileName) like '%.JPEG' or upper(vDocFileName) like '%.PNG' then
           update r5docentities
           set dae_printonwo = '+'
           where dae_entity = dae.dae_entity and dae_Code = dae.dae_code
           and   dae_document = dae.dae_document;
           
         end if;
     end if;
   end if;
   
exception 
  when others then
  RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex r5docentities/Post Insert/30/'||substr(SQLERRM, 1, 500)) ; 
end;
