declare 
  dae r5docentities%rowtype;
  vKeyFld1  r5documents.doc_udfchar01%type;
  vKeyFld2  r5documents.doc_udfchar01%type;
begin
  select * into dae from r5docentities where rowid=:rowid;
  if dae.dae_entity in ('TASK','OPCL','PPM','OBJ') then
     if instr(dae.dae_code,'#') > 0 then
        vKeyFld1 := substr(dae.dae_code,1,instr(dae.dae_code,'#')-1);
        vKeyFld2 := substr(dae.dae_code,instr(dae.dae_code,'#')+1);
     else
        vKeyFld1 := dae.dae_code;
     end if;
     
     update r5documents
     set doc_udfchar01 = dae.dae_entity,
     doc_udfchar02 = vKeyFld1,
     doc_udfchar03 = vKeyFld2
     where doc_code = dae.dae_document
     and   doc_udfchar01 is null;
     
  end if;
   
exception 
  when others then
     RAISE_APPLICATION_ERROR (  -20003,'Error in Flex r5docentities/Post Insert/50/'||substr(SQLERRM, 1, 500)) ; 
end;