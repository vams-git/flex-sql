declare 
  dae          r5docentities%rowtype;
  vCount       number;
  vDesc        varchar2(200); 
  vOrigDocDesc r5documents.doc_desc%type;
  err_msg      exception;
  vMessage     varchar2(4000);
begin
   select * into dae from r5docentities 
   where rowid=:rowid;

   if dae.dae_entity='EVNT' then
     --check is copy from PPM or task? doc_code is from PPM or is EVNTXXX
     --Check is Copy to WorkOrder-->Copy Link
     select count(1)  
     into   vCount
     from   r5docentities dae_1
     where  dae_1.dae_document=dae.dae_document
     and    dae_1.dae_entity NOT IN ('EVNT')
     and    dae_1.dae_copytowo = '+'
     and    dae_1.rowid<>:rowid; 
     --v_count:=1;
     --Check is Copy to WorkOrder-->Copy Document
     select doc_desc
     into   vOrigDocDesc--count (1) into vcnt
     from   r5documents
     where  doc_code = dae.dae_document;
     /*vMessage := vCount;
     raise err_msg;*/
     
     if vCount > 0 or vOrigDocDesc ='EVNT'||dae.dae_code then
        return;
     end if;
     
      select count(1) into vCount
      from   r5activities 
      where  act_event = dae.dae_code
      and    act_task in ('GOV-SAF-T-0001','GOV-IMP-T-0001');
      if vCount > 0 then
         select evt_udfchar06 || '-' || to_char(o7gttime(evt_org),'MMDD_HH24MM')
         into   vDesc
         from   r5events 
         where  evt_code =  dae.dae_code;
         
         update r5documents
         set doc_desc=substr(vDesc,1,80)
         where doc_code=dae.dae_document
         and   doc_desc = doc_filename;
      end if;
    
     
   end if;
exception 
  when err_msg then
  RAISE_APPLICATION_ERROR (-20001,vMessage);
  when no_data_found then
  null;
end;
