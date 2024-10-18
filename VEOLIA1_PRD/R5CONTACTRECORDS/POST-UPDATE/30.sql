declare 
  ctr          r5contactrecords%rowtype;
  vLocale      r5organization.org_locale%type;
  vCount       number;
  vNote        r5contactrecords.ctr_note%type;
  vNoteExists  varchar2(1);
  vAddLine     r5addetails.add_line%type;
  iErrMsg      varchar2(400);
  err_val      exception;
begin
  --This is post UPDATE on call center for updating comment for ctr_udfchkbox01
  select * into ctr from r5contactrecords where rowid=:rowid;
  select org_locale into vLocale from r5organization where org_code=ctr.ctr_org;
  if vLocale = 'NZ' then
    vNote := '3rd party damage has been selected for this WO from Call Centre ' || ctr.ctr_code ||' ';
    vNoteExists := 'N';
    begin
      select add_line into vAddLine from
      (select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text
       from r5addetails
       where add_entity='COCT' and add_code=ctr.ctr_code||'#'||ctr.ctr_org)
      where add_text like '3rd party damage has been selected for this WO from Call Centre%';
      vNoteExists := 'Y';
    exception when no_data_found then
      select nvl(max(add_line),0) + 10 into vAddLine
      from r5addetails where add_entity='COCT' and add_code = ctr.ctr_code||'#'||ctr.ctr_org;
    end;
    if ctr.ctr_udfchkbox01 ='+' and vNoteExists ='N' then
       insert into r5addetails
       (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text)
       values
       ('COCT','COCT','*','*',ctr.ctr_code||'#'||ctr.ctr_org,'EN',vAddLine,'+',vNote);
    end if;
    if ctr.ctr_udfchkbox01 ='-'and vNoteExists ='Y' then
       delete from r5addetails
       where add_entity = 'COCT' and add_code = ctr.ctr_code||'#'||ctr.ctr_org and add_line = vAddLine;
    end if;
    
    if ctr.ctr_event is not null then
         vNoteExists := 'N';
          begin
            select add_line into vAddLine from
            (select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text
             from r5addetails
             where add_entity='EVNT' and add_code= ctr.ctr_event)
            where add_text like '3rd party damage has been selected for this WO from Call Centre%';
            vNoteExists := 'Y';
          exception when no_data_found then
            select nvl(max(add_line),0) + 10 into vAddLine
            from r5addetails where add_entity='EVNT' and add_code = ctr.ctr_event;
          end;
          if ctr.ctr_udfchkbox01 ='+' and vNoteExists ='N' then
             insert into r5addetails
             (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text)
             values
             ('EVNT','EVNT','*','*',ctr.ctr_event,'EN',vAddLine,'+',vNote);
          end if;
          if ctr.ctr_udfchkbox01 ='-'and vNoteExists ='Y' then
             delete from r5addetails
             where add_entity = 'EVNT' and add_code = ctr.ctr_event and add_line = vAddLine;
          end if;
    end if;
    
  end if;
  
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
/*when others then
    RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5contactrecords/Post Insert/10/'||substr(SQLERRM, 1, 500));*/
end;
