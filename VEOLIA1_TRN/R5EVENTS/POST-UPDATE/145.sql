declare 
  evt               r5events%rowtype; 
  vLastReading      r5readings.rea_reading%type;
  vNextMeterDue     r5events.evt_meterdue%type;
  vNote             varchar2(4000);
  vAddLine          r5addetails.add_line%type;
  vPriority         u5iusvpmatrix.ium_priority%type;
  vCount            number;
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('PPM') AND evt.evt_status in ('25TP') and evt.evt_meterdue is not null then
     begin
     select rea_reading into vLastReading from
     (select rea_reading
     from   r5readings
     where  rea_object = evt.evt_object and rea_object_org = evt.evt_object_org
     and    rea_uom = evt.evt_metuom
     order by rea_date desc)
     where rownum<=1;
     exception when no_data_found then
        vLastReading := 0;
     end;
     
     vNextMeterDue := evt.evt_meterdue + nvl(evt.evt_meterinterval,0);
     
     vNote := 'Work Order generated from routine ' || evt.evt_ppm || ' ' || evt.evt_desc || chr(10) 
                || 'Service due is ' || evt.evt_meterdue || ' ' ||evt.evt_metuom || chr(10) 
                || 'Current meter value is ' || vLastReading || ' ' || r5o7.o7get_desc('EN','UOM',evt.evt_metuom,'','') || chr(10) 
                || 'Next service due is ' || vNextMeterDue || ' ' ||evt.evt_metuom || chr(10) 
                ; 
     
     begin
      select add_line into vAddLine from
      (select add_line,
       --U7GETADDETAILS(add_entity,add_type,add_code,add_line)as add_text
       R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text
       from r5addetails
       where add_entity='EVNT' and add_code= evt.evt_code)
       where add_text like 'Work Order generated from routine %';
     exception when no_data_found then
       select nvl(max(add_line),0) + 10 into vAddLine
       from r5addetails where add_entity='EVNT' and add_code = evt.evt_code;

       insert into r5addetails
       (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created,add_user)
       values
       ('EVNT','EVNT','*','*',evt.evt_code,'EN',vAddLine,'+',vNote,o7gttime(evt.evt_org),o7sess.cur_user);
     end;
  end if;
  
  if evt.evt_org in ('QTN') and evt.evt_status in ('50SO') and evt.evt_serviceproblem is not null then
     begin
       select ium_priority into vPriority from u5iusvpmatrix
       where ium_spb = evt.evt_serviceproblem
       and   ium_priority like '%CBD SH%'
       and rownum <= 1;
       
       if instr(upper(vPriority),'NON') > 0 then
         vPriority := 'Non_CBD_SH';
       else 
         vPriority := 'CBD_SH';
       end if;
       vNote := 'Client LocationCategory: ' || vPriority;
       
       select count(add_line),min(add_line) into  vCount,vAddLine
       from r5addetails 
       where  add_rentity = 'EVNT' and add_type = '*'
       and    add_code = evt.evt_code
       and    R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)
       like   'Client LocationCategory: %';
       if vCount = 0 then
          select nvl(max(add_line),0) + 10 into vAddLine
          from r5addetails where add_entity='EVNT' and add_code = evt.evt_code;
       
           insert into r5addetails
          (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created,add_user)
           values
          ('EVNT','EVNT','*','*',evt.evt_code,'EN',vAddLine,'+',vNote,o7gttime(evt.evt_org),'MIGRATION');
        end if;        
     exception when no_data_found then
       null;
     end;
     
  end if;
end;