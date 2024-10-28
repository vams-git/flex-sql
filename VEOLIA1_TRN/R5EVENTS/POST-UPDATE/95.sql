declare 
 evt             r5events%rowtype;
 spb             r5serviceproblemcodes%rowtype;
 vLocale         r5organization.org_locale%type;
 vUdfNumb03      r5events.evt_udfnum03%type;
 vNewStatus      r5audvalues.ava_to%type;
 vOldStatus      r5audvalues.ava_from%type;
 vPopulateBy48MR varchar2(1);
 vNewSPB         r5audvalues.ava_to%type;
 vOldSPB         r5audvalues.ava_from%type;
 vTimeDiff       number;
 vIsSPBUpdate    varchar2(1);
 vUdfdate05      r5events.evt_udfdate05%type;
 vTfpromisedate  r5events.evt_tfpromisedate%type;
 vTfdatecompleted  r5events.evt_tfdatecompleted%type;
 vPfpromisedate    r5events.evt_pfpromisedate%type;
 vCalGroup         r5organization.org_calgroupcode%type;
 
 vComment          VARCHAR2(4000);
 vAddLine          R5ADDETAILS.ADD_LINE%TYPE;
 vNewKPIDate       date;
 vKPIOldDate       date;
 vCount            number;

 
FUNCTION FUN_U5GETSPBKPIDAY
(pOrg               in varchar2,
 pCalGroup          in varchar2,
 pStartDate         in date,
 pKPIValue          in number,
 pKPIUnit           in varchar2
) RETURN DATE AS

 vReturnDate   DATE;
 vKPIDays      NUMBER;
 vCount        NUMBER;

BEGIN

  if pKPIUnit = 'MINUTES' then
    vReturnDate := pStartDate + (pKPIValue/24/60);
  elsif pKPIUnit = 'HOURS' then
    vReturnDate := pStartDate + (pKPIValue/24);
  else
    if pKPIUnit = 'DAYS' then
      vKPIDays := pKPIValue;
    elsif pKPIUnit = 'WEEKS' then
      vKPIDays := pKPIValue * 7;
    elsif pKPIUnit = 'MONTHS' then
      vKPIDays := trunc(add_months(pStartDate,pKPIValue)) - trunc(pStartDate);
    elsif pKPIUnit = 'YEARS' then
      vKPIDays := trunc(add_months(pStartDate,pKPIValue * 12)) - trunc(pStartDate);
    end if;

    select count(1) into vCount
    from   U5CCTRCALDAYS  --may change table name
    where  CGD_GROUPORG = pOrg
    and    CGD_GROUPCODE = pCalGroup;

    if vCount > 0 then
      SELECT MAX (SUB.CGD_DATE + vKPIDays - SUB.DAYS_COUNT)
      INTO vReturnDate
      FROM
      (SELECT
         CGD_DATE,
         (CGD_DATE - trunc(pStartDate))- COUNT (1) OVER (ORDER BY CGD_DATE) DAYS_COUNT
         FROM U5CCTRCALDAYS --may change table name
         WHERE CGD_DATE > trunc(pStartDate)
         AND   CGD_ISNONWORK='+'
         AND   CGD_GROUPORG = pOrg
         AND   CGD_GROUPCODE = pCalGroup
         --AND   CGD_PERIOD = 'WCR-2015'
       UNION
       SELECT trunc(pStartDate), 0 FROM DUAL) SUB
      WHERE SUB.DAYS_COUNT < vKPIDays;
   else
     vReturnDate := pStartDate + vKPIDays;
   end if;
   if vReturnDate is not null then
        vReturnDate:=to_date(to_char(vReturnDate,'YYYY-MON-DD')||' 23:59:59','YYYY-MON-DD HH24:MI:SS');
     end if;
  end if;

  return vReturnDate;

END FUN_U5GETSPBKPIDAY;
 
 
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
     select org_locale into vLocale from r5organization where org_code = evt.evt_org;
     if vLocale in ('NZ') then
        if evt.evt_serviceproblem is not null then
          begin
           select org_calgroupcode--org_udfchar07
            into   vCalGroup
            from   r5organization
            where org_code = evt.evt_org;
                  
            select * into spb from r5serviceproblemcodes 
            where spb_code = evt.evt_serviceproblem and spb_org = evt.evt_serviceproblem_org;
          exception when no_data_found then
            vCalGroup:=NULL;
          end;
        end if;
        
        --update KPI GAP evt_udfnum03 to 1 if there is gap.
        if evt.evt_start      > evt.evt_udfdate05 or
           evt.evt_udfdate02  > evt.evt_tfpromisedate or
           evt.evt_udfdate03  > evt.evt_tfdatecompleted or
           evt.evt_completed  > evt.evt_pfpromisedate
        then
          vUdfNumb03 := 1;
        else
          vUdfNumb03 := null;
        end if;
        if nvl(evt.evt_udfnum03,-1) <> nvl(vUdfNumb03,-1) then
           update r5events
           set    evt_udfnum03 = vUdfNumb03
           where  evt_code = evt.evt_code;
        end if;
    
        --UPDATE KPI DATE WHEN STATUS CHANGE T0 48MR
        vPopulateBy48MR := '-';
        if evt.evt_status = '48MR' and nvl(evt.evt_sourcesystem,'NA') not in ('WBOPDC') and evt.evt_serviceproblem is not null then        
           begin
              select ava_to,ava_from,timediff into vNewStatus,vOldStatus,vTimeDiff
              from (
              select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
              from r5audvalues,r5audattribs
              where ava_table = aat_table and ava_attribute = aat_code
              and   aat_table = 'R5EVENTS' and aat_column in ('EVT_STATUS')
              and   ava_table = 'R5EVENTS' 
              and   ava_primaryid = evt.evt_code
              --and  ava_updated = '+'
              --and ava_inserted ='+'
              and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
              order by ava_changed desc
              ) where rownum <= 1;   
              if spb.spb_permfixturnaround is not null and spb.spb_permturnaroundunit is not null then
                if nvl(spb.spb_udfchkbox01,'-') = '+' and evt.evt_udfdate03 is not null then
                   vPfpromisedate := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_udfdate03,spb.spb_permfixturnaround,spb.spb_permturnaroundunit);
                   update r5events
                   set   evt_pfpromisedate = vPfpromisedate
                   where  evt_code = evt.evt_code
                   and    nvl(evt_pfpromisedate,to_date('1900-01-01','YYYY-MM-DD')) <> nvl(vPfpromisedate,to_date('1900-01-01','YYYY-MM-DD'));
                   vPopulateBy48MR := '+';
                end if;
              end if;
           exception when no_data_found then 
              vNewStatus := null;
           end; 
        end if;
        
        begin
            select ava_to,ava_from,timediff into vNewSPB,vOldSPB,vTimeDiff
            from (
            select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
            from r5audvalues,r5audattribs
            where ava_table = aat_table and ava_attribute = aat_code
            and   aat_table = 'R5EVENTS' and aat_column in ('EVT_SERVICEPROBLEM')
            and   ava_table = 'R5EVENTS' 
            and   ava_primaryid = evt.evt_code
            and  ava_updated = '+'
            --and ava_inserted ='+'
            and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 1
            order by ava_changed desc
            ) where rownum <= 1;   
            vIsSPBUpdate := 'Y';
         exception when no_data_found then 
            vIsSPBUpdate := 'N';
         end;
         
         
         if vIsSPBUpdate = 'Y' and nvl(evt.evt_sourcesystem,'NA') not in ('WBOPDC') and nvl(vOldSPB,' ') not like '%DFLT-KPI%' then
            --RESET KPI DATE
            vUdfdate05 := null;
            vTfpromisedate := null;
            vTfdatecompleted := null;
            vPfpromisedate := null;
            if evt.evt_serviceproblem is not null then
               if evt.evt_reported is not null then
                  if spb.spb_udfnum01 is not null and spb.spb_udfchar01 is not null then
                     vUdfdate05 := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_reported,spb.spb_udfnum01,spb.spb_udfchar01);
                  end if;

                  if spb.spb_tempfixturnaround is not null and spb.spb_tempturnaroundunit is not null then
                     vTfpromisedate := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_reported,spb.spb_tempfixturnaround,spb.spb_tempturnaroundunit);
                  end if;

                  if spb.spb_udfnum02 is not null and spb.spb_udfchar02 is not null then
                     vTfdatecompleted := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_reported,spb.spb_udfnum02,spb.spb_udfchar02);
                  end if;
              end if;

              if spb.spb_permfixturnaround is not null and spb.spb_permturnaroundunit is not null then
                if nvl(spb.spb_udfchkbox01,'-') = '-' and evt.evt_reported is not null then
                   vPfpromisedate := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_reported,spb.spb_permfixturnaround,spb.spb_permturnaroundunit);
                end if;
                if nvl(spb.spb_udfchkbox01,'-') = '+' and evt.evt_udfdate03 is not null then
                   vPfpromisedate := FUN_U5GETSPBKPIDAY(evt.evt_org,vCalGroup,evt.evt_udfdate03,spb.spb_permfixturnaround,spb.spb_permturnaroundunit);
                end if;
              end if;
            end if;--if evt.evt_serviceproblem is not null then
            --UPDATE kip date
            update r5events
            set    evt_udfdate05 = vUdfdate05,
                   evt_tfpromisedate = vTfpromisedate,
                   evt_tfdatecompleted = vTfdatecompleted,
                   evt_pfpromisedate = vPfpromisedate
            where  evt_code = evt.evt_code
            and    (
            nvl(evt_udfdate05,to_date('1900-01-01','YYYY-MM-DD')) <> nvl(vUdfdate05,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(evt_tfpromisedate,to_date('1900-01-01','YYYY-MM-DD')) <> nvl(vTfpromisedate,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(evt_tfdatecompleted,to_date('1900-01-01','YYYY-MM-DD')) <> nvl(vTfdatecompleted,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(evt_pfpromisedate,to_date('1900-01-01','YYYY-MM-DD')) <> nvl(vPfpromisedate,to_date('1900-01-01','YYYY-MM-DD'))
            );
            
            --Insert Comment
            
            vComment:= 'Contract KPI Codes was changed to '||
            evt.evt_serviceproblem || ' ' ||
            r5o7.o7get_desc('EN', 'SVPB', evt.evt_serviceproblem || '#' || evt.evt_serviceproblem_org, '', '')
            ||chr(10)||'New Target KPI values for this WO are:'
            ||chr(10)||'Respond By - KPI: '||to_char(vUdfdate05,'MON-DD-YYYY HH24:mi')
            ||chr(10)||'First Repair - KPI: '||to_char(vTfpromisedate,'MON-DD-YYYY HH24:mi')
            ||chr(10)||'Restoration - KPI: '||to_char(vTfdatecompleted,'MON-DD-YYYY HH24:mi')
            ||chr(10)||'Date Completed - KPI:'|| to_char(vPfpromisedate,'MON-DD-YYYY HH24:mi')
            ;
            
             select count(1) into vCount from
             (select add_line,
             R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text,
             add_created
             from r5addetails
             where add_entity='EVNT' and add_code= evt.evt_code
             and   abs(o7gttime(evt.evt_org) - add_created) * 24 * 60 * 60 < 1)
             where add_text like vComment;
             if vCount = 0 then
                select nvl(max(add_line),0) + 10 into vAddLine
                from r5addetails where add_entity='EVNT' and add_code = evt.evt_code;
                insert into r5addetails
                (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
                values
                ('EVNT','EVNT','*','*',evt.evt_code,'EN',vAddLine,'+',vComment,o7gttime(evt.evt_org));
             end if;
         end if; -- if vIsSPBUpdate = 'Y'

     end if;
  end if;   
 

exception 
when no_data_found then
     return;  
/*WHEN others THEN 
    RAISE_APPLICATION_ERROR ( -20003,'Error in Flex/R5EVENTS/95/Update') ; */
end;