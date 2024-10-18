declare 
  cursor cur_ctr is 
  select ctr_org,ctr_event,ctr_code
  from r5contactrecords,r5events
  where ctr_event = evt_code
  and   ctr_org = 'QTN' and evt_org = 'QTN'
  and   ctr_createdby ='MIGRATION'
  and   ctr_status = 'O' 
  and   nvl(evt_udfchar26,' ') <>　ctr_code
  and   evt_status = '25TP';
  
  cursor cur_sapinv is 
  select ion_keyfld1, ion_keyfld2,ion_wsscode
  from u5ionmonitor 
  where ion_source = 'SAP' and ion_destination = 'EAM'
  and   ion_trans ='INV' 
  and   ion_status ='Failed'
  and   instr(ion_message,'Supplier is invalid') > 0
  and   exists (select 1 from r5companies where nvl(com_notused,'-') = '-'  and com_code = ion_keyfld2)
  and   exists (select 1 from r5wsmessagestatus where wss_code = ion_wsscode and wss_req_status ='F' and wss_retry_count =0)
  and   ion_create >= add_months(sysdate,-3);
  
  
  ucd          u5vucosd%rowtype;
  ctr          r5contactrecords%rowtype;
  vLocale      r5organization.org_locale%type;
  vCount       number;
  
  vTarget      r5events.evt_target%type;
  vSchEnd      r5events.evt_schedend%type;
  
  vDesc        varchar2(4000);
  sql_stmt      varchar2(4000);
  vFieldValue  varchar2(4000);
  
  vKPIComment  varchar2(4000);
  vAddLine     r5addetails.add_line%type;
  
  iErrMsg      varchar2(400);
  err_val      exception;
  
  
  cursor cur_ctrfield(vOrg varchar2) is
  select fld.cfd_field,fld.cfd_entity,fld.description,fld.cfd_fieldvalue
  from U5CUFLDR FLD,U5CUWODC WO
  where fld.cfd_field = wo.cuw_field
  and wo.cuw_org = vOrg
  order by wo.cuw_sequence;
begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 30 and ucd.ucd_recalccost = '+' then
      --to reprocess qtn inbound data when Work order data is missing
      for rec in cur_ctr loop
          select * into ctr from r5contactrecords where ctr_code = rec.ctr_code;
          begin
              select min(schstart),max(schstart) into vTarget,vSchEnd from
              (select ctr.ctr_udfdate03 as schstart from dual where ctr.ctr_udfdate03 is not null
              union
              select ctr.ctr_temppromiseddate as schstart from dual where ctr.ctr_temppromiseddate is not null
              union
              select ctr.ctr_udfdate04 as schstart from dual where ctr.ctr_udfdate04 is not null
              union
              select ctr.ctr_promiseddate as schstart from dual where ctr.ctr_promiseddate is not null
              );
                    
              --Update work order desc by call cetre or work order value. 
              for rec_field in cur_ctrfield(ctr.ctr_org) loop
               if vDesc is null or length(vDesc) <= 81 then
                  if rec_field.cfd_entity = 'CONT' then
                    sql_stmt := 'SELECT '||rec_field.cfd_fieldvalue || ' from r5contactrecords where ctr_code = :vCode';
                    EXECUTE IMMEDIATE sql_stmt INTO vFieldValue USING ctr.ctr_code;
                  end if;
                  if rec_field.cfd_entity = 'EVNT' then
                    sql_stmt := 'SELECT '||rec_field.cfd_fieldvalue || ' from r5events where evt_code = :vCode';
                    EXECUTE IMMEDIATE sql_stmt INTO vFieldValue USING ctr.ctr_event;
                  end if;
                  select vDesc || decode(vFieldValue,null,null,'-'||vFieldValue) into vDesc from dual;
                end if;
              end loop;
                    
              --Copy ctr feilds to work order
              update r5events
              set   evt_desc = nvl(substr(vDesc,2,80),evt_desc),
                    evt_person = ctr.ctr_assignedto,
                    evt_udfchar29 = ctr.ctr_mrc,
                    --evt_udfdate02 = :new.ctr_udfdate02,
                    evt_reported = ctr.ctr_udfdate02,
                    evt_requeststart = ctr.ctr_udfdate02,
                    evt_udfchar28 = nvl(ctr.ctr_udfchar08,evt_udfchar28),
                    evt_udfdate05 = ctr.ctr_udfdate03,
                    evt_tfpromisedate = ctr.ctr_temppromiseddate,
                    evt_tfdatecompleted = ctr.ctr_udfdate04,
                    evt_pfpromisedate = ctr.ctr_promiseddate,
                    evt_target = vTarget,
                    evt_schedend =vSchEnd,--nvl(:new.ctr_promiseddate,vTarget),
                    evt_udfchar26 = ctr.ctr_code,
                    evt_udfnum01=ctr.ctr_udfnum01,
                    evt_udfchkbox04=ctr.ctr_udfchkbox04,
                    evt_sourcesystem = ctr.ctr_udfchar30,
                          
                    evt_latitude = ctr.ctr_udfnum04,
                    evt_longitude = ctr.ctr_udfnum05,
                    evt_class = ctr.ctr_woclass,
                    evt_class_org = ctr.ctr_woclass_org,
                    evt_serviceproblem = ctr.ctr_serviceproblem,
                    evt_serviceproblem_org = ctr.ctr_serviceproblem_org,
                    evt_priority = ctr.ctr_priority
              where  evt_code = ctr.ctr_event and evt_org = ctr.ctr_event_org;
              
              --add wo comment for KPI/date
              if ctr.ctr_serviceproblem not like '%DFLT-KPI%' then
                vKPIComment :=
                      'Original Target KPI values for this WO are:' || chr(10)
                      || 'Respond By - KPI: ' || to_char(ctr.CTR_UDFDATE03,'DD-MON-YYYY HH24:mi') || chr(10)
                      || 'First Repair - KPI: '|| to_char(ctr.CTR_TEMPPROMISEDDATE ,'DD-MON-YYYY HH24:mi')|| chr(10)
                      || 'Restoration - KPI: ' || to_char(ctr.CTR_UDFDATE04,'DD-MON-YYYY HH24:mi') || chr(10)
                      || 'Date Completed - KPI: '||to_char(ctr.CTR_PROMISEDDATE,'DD-MON-YYYY HH24:mi') || chr(10)
                      || chr(10)
                      || 'Client contact details:' || chr(10)
                      || 'First name: '||ctr.CTR_FIRSTNAME || chr(10)
                      || 'Last name: '||ctr.CTR_LASTNAME || chr(10)
                      || 'Phone number: '||ctr.CTR_PRIMARYPHONE || chr(10)
                      || 'Work Address: '||ctr.CTR_WORKADDRESS || chr(10)
                      || 'CCRID Number: '||ctr.CTR_UDFCHAR10;
                begin
                  select add_line into vAddLine from
                  (select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)as add_text
                   from r5addetails
                   where add_entity='EVNT' and add_code=ctr.ctr_event and add_lang = 'EN')
                  where add_text like 'Original Target KPI values for this WO%';
                        
                 exception when no_data_found then
                   select nvl(max(add_line),0) + 10 into vAddLine
                   from r5addetails where add_entity='EVNT' and add_code = ctr.ctr_event;

                   insert into r5addetails
                   (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
                   values
                   ('EVNT','EVNT','*','*',ctr.ctr_event,'EN',vAddLine,'+',vKPIComment,o7gttime(ctr.ctr_org));
                 end;
               end if; --end ctr_serviceproblem not like '%DFLT-KPI-0000' 
          exception when others then 
            null;
          end;
      end loop; -- end cur_ctr
      
      for rec_inv in cur_sapinv loop
          begin 
            update r5wsmessagestatus
            set    wss_retry_count = 1,wss_retry_time = sysdate + INTERVAL '1' MINUTE
            where  wss_code = rec_inv.ion_wsscode;
          exception when others then 
            null;
          end; 
      end loop;-- end rec_inv
    update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
    end if;
  
end;