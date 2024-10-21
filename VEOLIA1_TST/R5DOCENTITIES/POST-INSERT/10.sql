declare 
  dae           r5docentities%rowtype;
  v_count       number;
  v_OrigDocDesc r5documents.doc_desc%type;
  v_Desc        r5events.evt_desc%type;    
begin
   select * into dae from r5docentities 
   where rowid=:rowid;

   if dae.dae_entity='EVNT' then
     --check is copy from PPM? doc_code is from PPM or is EVNTXXX
     select count(1)  
     into   v_count
     from   r5docentities
     where  dae_document=dae.dae_document
     and    dae_entity='PPM'
     and    rowid<>:rowid; 
     --v_count:=1;

     select doc_desc
     into   v_OrigDocDesc--count (1) into vcnt
     from   r5documents
     where  doc_code = dae.dae_document;
     
     if v_count > 0 or v_OrigDocDesc ='EVNT'||dae.dae_code then
       null;
       --do notthing is due to pm copied doc
     else
       begin 
         select
         evt_code||'#'||evt_udfchar28||'#'||to_char(o7gttime(evt_org),'YYYYMMDDHHMMSS')
         into
         v_Desc
         from r5events,r5organization
         where evt_org = org_code
         and   evt_code = dae.dae_code
         --and   evt_org not in ('WCC','WEW')
         and   org_locale in ('NZ');

         update r5documents
         set doc_desc=substr(v_Desc,1,80)
         where doc_code=dae.dae_document;
       exception 
         when no_data_found then 
         null;
         when others then
         null;
       end;  
     end if;
   end if;
  
end;
