declare 
  dae r5docentities%rowtype;
  vClass r5classes.cls_code%type;
begin
  select * into dae from r5docentities where rowid=:rowid;
  if dae.dae_entity ='OBJ' then
     select doc_class into vClass 
     from   r5documents 
     where  doc_code = dae.dae_document;
     
     if vClass  ='PHOTO' then
         delete from r5docentities 
         where dae_entity ='OBJ' and dae_code = dae.dae_code 
         and   dae_document <> dae.dae_document
         and   dae_document in 
         (select doc_code 
          from r5documents doc1,r5docentities dae1
          where doc1.doc_code = dae1.dae_document
          and   doc1.doc_class ='PHOTO'
          and   dae1.dae_code = dae.dae_code);
     end if;
  end if;
  
end;