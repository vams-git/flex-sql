declare 
  evt               r5events%rowtype; 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  vCount            number;
  
  vNote             varchar2(4000);
  vAddLine          r5addetails.add_line%type;
begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
    if evt.evt_org in ('QTN') and evt.evt_workaddress is not null then
       if o7sess.cur_user not in ('MIGRATION') then
          if evt.evt_status in ('40PR') and (evt.evt_latitude is null or evt.evt_longitude is null) then
             iErrMsg := 'Please validate work address by submitting the address from Map.';
             raise err_chk;
          end if;
       end if;
    end if;
      
    IF evt.evt_org in ('WBP','QTN') and evt.evt_status IN ('31DU') and evt.evt_parent is null THEN
        if evt.evt_udfchar27 is null then
           iErrMsg := 'This workorder is unable to move to Duplicated as is Client/Master WR/WO Empty';
           raise err_chk;
        end if;
        
        
        vNote := 'Duplicate job. Original job number is ' || evt.evt_udfchar27;
        begin
          select add_line into vAddLine from
          (select add_line,
          R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text
           from r5addetails
           where add_entity='EVNT' and add_code= evt.evt_code)
          where add_text like 'Duplicate job. Original job number is %';
          
          update r5addetails
          set add_text = vNote,
              add_updated = o7gttime(evt.evt_org),
              add_upduser = o7sess.cur_user
              where add_entity='EVNT' and add_code= evt.evt_code and add_line = vAddLine;
         exception when no_data_found then
           select nvl(max(add_line),0) + 10 into vAddLine
           from r5addetails where add_entity='EVNT' and add_code = evt.evt_code;

           insert into r5addetails
           (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created,add_user)
           values
           ('EVNT','EVNT','+','*',evt.evt_code,'EN',vAddLine,'+',vNote,o7gttime(evt.evt_org),o7sess.cur_user);
         end;
         
      END IF;
  end if; 
  
EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/230/'||substr(SQLERRM, 1, 500)) ;
end;