declare 
    evt r5events%rowtype;
    
    CURSOR c_PPMDocs(vDaeCode varchar2) IS
    SELECT dae_document,dae_entity,dae_code,doc_udfchkbox01,doc_udfchkbox02
    FROM   r5documents, r5docentities
    WHERE  doc_code = dae_document
    AND    dae_rentity = 'PPM'
    AND    dae_code like vDaeCode
    AND    doc_udfchkbox01 = '+'
    AND    doc_notused = '-';
    
    CURSOR c_StandWODocs(vDaeCode varchar2) IS
    SELECT dae_document,dae_entity,dae_code,doc_udfchkbox01,doc_udfchkbox02
    FROM   r5documents, r5docentities
    WHERE  doc_code = dae_document
    AND    dae_rentity = 'STWO'
    AND    dae_code = vDaeCode
    AND    doc_udfchkbox01 = '+'
    AND    doc_notused = '-';
 

begin
    select * into evt from r5events where rowid=:rowid;
    if evt.evt_type in ('PPM') and evt.evt_ppm is not null then
       for rec_ppmdoc in c_PPMDocs(evt.evt_ppm||'#'||evt.evt_ppmrev) loop
           INSERT INTO r5docentities
           ( dae_document,dae_entity, dae_rentity,
              dae_type,dae_rtype,dae_code,dae_printonpo, dae_printonwo)
           values
           (rec_ppmdoc.dae_document,'EVNT','EVNT','*','*',evt.evt_code,'-',rec_ppmdoc.doc_udfchkbox02);
       end loop;
    end if;
    
    if evt.evt_standwork is not null then
        for rec_stddoc in c_StandWODocs(evt.evt_standwork) loop
           INSERT INTO r5docentities
           ( dae_document,dae_entity, dae_rentity,
              dae_type,dae_rtype,dae_code,dae_printonpo, dae_printonwo)
           values
           (rec_stddoc.dae_document,'EVNT','EVNT','*','*',evt.evt_code,'-',rec_stddoc.doc_udfchkbox02);
       end loop;
    end if;

exception 
  when others then
  RAISE_APPLICATION_ERROR ( SQLCODE,'ERR/R5EVENTS/30/I - '||substr(SQLERRM, 1, 500)) ;     
end;
