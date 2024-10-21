declare 
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
  --This is post UPDATE on call center for updating work order when work order changes or KPI Code changes
  select * into ctr from r5contactrecords where rowid=:rowid;
  select org_locale into vLocale from r5organization where org_code=ctr.ctr_org;
  if vLocale = 'NZ' then
    if ctr.ctr_event is not null and ctr.ctr_duplicate ='-' then
        --only trigger when work order or contract kpi is updated. 
        if ctr.ctr_org in ('QTN') then
          select count(1) into  vCount
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5CONTACTRECORDS' and aat_column IN ('CTR_SERVICEPROBLEM','CTR_EVENT')
          and   ava_table = 'R5CONTACTRECORDS' 
          and   ava_primaryid = ctr.ctr_code and ava_secondaryid = ctr.ctr_org
          and   ava_updated = '+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 5;
        else
          select count(1) into  vCount
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5CONTACTRECORDS' and aat_column IN ('CTR_EVENT')
          and   ava_table = 'R5CONTACTRECORDS' 
          and   ava_primaryid = ctr.ctr_code and ava_secondaryid = ctr.ctr_org
          and   ava_updated = '+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 5;
        end if;
        if vCount > 0 then 
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
            
            --reset kpi adjusted flag
            /*update r5events set evt_udfchkbox03='-'
            where evt_code = ctr.ctr_event and evt_org = ctr.ctr_event_org;*/
            
            /*
            if vDesc is not null then
               update r5events
               set evt_desc = substr(vDesc,2,80)
               where evt_code = ctr.ctr_event and evt_org = ctr.ctr_org
               and evt_desc <> substr(vDesc,2,80)
               and evt_status = '25TP';
            end if;*/
            
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
             
        end if;
    end if;
  end if;
  
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
/*when others then
    RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5contactrecords/Post Insert/10/'||substr(SQLERRM, 1, 500));*/
end;