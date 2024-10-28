declare 
  evt           r5events%rowtype;
  
  vComment      varchar2(4000);
  vAddLine      r5addetails.add_line%type;



begin
    select * into evt from r5events where rowid=:rowid;--evt_code = '1005429161';--
    
    if evt.evt_type in ('JOB') and evt.evt_parent is null and evt.evt_status ='15TV' then
	    vComment:='Reject Reason Details:';
		
        begin
		select add_line into vAddLine from
		(select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)as add_text
		 from r5addetails
		 where add_entity='EVNT' and add_code=evt.evt_code and add_lang = 'EN')
		where add_text like 'Reject Reason Details%';
		
	    exception when no_data_found then
		   vAddLine := 1;
		   insert into r5addetails
		   (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
			values
		   ('EVNT','EVNT','*','*',evt.evt_code,'EN',vAddLine,'+',vComment,o7gttime(evt.evt_org));
        end;

    end if;

exception when others then 
  RAISE_APPLICATION_ERROR ( SQLCODE,'ERR/R5EVENTS/5/I - '||substr(SQLERRM, 1, 500));
end;
