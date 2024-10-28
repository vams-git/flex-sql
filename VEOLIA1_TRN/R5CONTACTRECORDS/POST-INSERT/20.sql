declare 
  ctr          r5contactrecords%rowtype;
  vCount       number;
  
  vUdfchar30   r5contactrecords.ctr_udfchar30%type;
  vNewKPICode  r5serviceproblemcodes.spb_code%type;
  vNewKPIOrg   r5serviceproblemcodes.spb_org%type;
  vOldKPICode  r5serviceproblemcodes.spb_code%type;
  
  vFailure     r5contactrecords.ctr_udfdate02%type;
  spb          r5serviceproblemcodes%rowtype;
  vCalGroup    r5cctrcalgroups.cgr_code%type;
  
  vUdfdate03        r5contactrecords.ctr_udfdate03%type;
  vTemppromiseddate r5contactrecords.ctr_temppromiseddate%type;
  vUdfdate04        r5contactrecords.ctr_udfdate04%type;
  vPromiseddate     r5contactrecords.ctr_temppromiseddate%type;
  
  vAddLine          r5addetails.add_line%type;
  vNoteToComm       varchar2(400);
  
  iErrMsg      varchar2(400);
  err_val      exception;
  
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
  --This is post insert on call center
  select * into ctr from r5contactrecords where rowid=:rowid;
  --Initial Failure time and KPI Code.
  vFailure := ctr.ctr_udfdate02;
  vNewKPICode := ctr.ctr_serviceproblem;
  vNewKPIOrg := ctr.ctr_serviceproblem_org;
  vUDFCHAR30 := nvl(ctr.ctr_udfchar30,'NA');
  --For QLDC Interface, set UDFDATE02 and Contract KPI Code
  if ctr.ctr_org = 'QTN' and ctr.ctr_serviceproblem like '%-DFLT-KPI%%' then
     vUdfchar30 :='QLDC';
     vFailure := nvl(ctr.ctr_udfdate02,o7gttime(ctr.ctr_org));
     begin
           select ium_spb,ium_spborg into vNewKPICode,vNewKPIOrg
           from   u5iusvpmatrix 
           where ium_wotype = ctr.ctr_udfchar02
           and   ium_mainttype = ctr.ctr_udfchar03
           and   ium_priority = ctr.ctr_udfchar04;

           select * into spb from r5serviceproblemcodes 
           where spb_code = vNewKPICode and spb_org = vNewKPIOrg;
           
           update r5contactrecords
           set    ctr_udfdate02 = vFailure,
                  ctr_Copynotetowo = '+',
                  ctr_udfchar30 = vUDFCHAR30,
                  ctr_serviceproblem = vNewKPICode,
                  ctr_serviceproblem_org = vNewKPIOrg,
                  ctr_woclass = spb.spb_woclass,
                  ctr_woclass_org = spb.spb_woclass_org,
                  ctr_priority = spb.spb_priority
           where  rowid=:rowid;
           
      exception when no_data_found then
           iErrMsg := 'Contract KPI Code is not found in Client Interface KPI Matrix';
           raise err_val;
      end;
  end if; --End For QLDC Interface
  
  --For WBOPDC interface, this update will trigger update r5events, kpiskip check by updatecount increase 1.
  if ctr.ctr_udfchar30 = 'WBOPDC' then
    vFailure := nvl(ctr.ctr_udfdate02,o7gttime(ctr.ctr_org));
    if ctr.ctr_udfdate02 is null then
     update r5contactrecords
     set    ctr_udfdate02 = vFailure
     where  ctr_udfdate02 is null 
     and    rowid =:rowid;
    else
     update r5contactrecords
     set    ctr_udfdate02 = vFailure
     where  rowid =:rowid;
    end if;
  end if;
  
  --Validate Same Client for interface
  select count(1) into vCount from r5contactrecords
  where --ctr_udfchar30  = vUDFCHAR30 
  ctr_org = ctr.ctr_org
  and   nvl(ctr_udfchar08, ' ') = ctr.ctr_udfchar08;
  if vCount >  1 then
     iErrMsg := 'Same Client Code is exists in VAMS';
     raise err_val;
  end if;
  
  --Record get from WBOPDC, skip kpi calcuation, the time will get from interface.
  if ctr.ctr_udfchar30 = 'WBOPDC' then
     return;
  end if;
  
  --Start to calculate KIP Time
  if vFailure is not null and vNewKPICode is not null then
     begin
        select org_calgroupcode--org_udfchar07
        into   vCalGroup
        from   r5organization
        where org_code = ctr.ctr_org;
        
        select * into spb from r5serviceproblemcodes 
        where spb_code = vNewKPICode and spb_org = vNewKPIOrg;
        
        vUdfdate03 := null;
        vTemppromiseddate := null;
        vUdfdate04 :=null;
        vPromiseddate := null;
      
        if spb.spb_udfnum01 is not null and spb.spb_udfchar01 is not null then
           vUdfdate03 := FUN_U5GETSPBKPIDAY(ctr.ctr_org,vCalGroup,vFailure,spb.spb_udfnum01,spb.spb_udfchar01);
        end if;

        if spb.spb_tempfixturnaround is not null and spb.spb_tempturnaroundunit is not null then
           vTemppromiseddate := FUN_U5GETSPBKPIDAY(ctr.ctr_org,vCalGroup,vFailure,spb.spb_tempfixturnaround,spb.spb_tempturnaroundunit);
        end if;

        if spb.spb_udfnum02 is not null and spb.spb_udfchar02 is not null then
           vUdfdate04 := FUN_U5GETSPBKPIDAY(ctr.ctr_org,vCalGroup,vFailure,spb.spb_udfnum02,spb.spb_udfchar02);
        end if;

         
        if nvl(spb.spb_udfchkbox01,'-') = '-' then
          if spb.spb_permfixturnaround is not null and spb.spb_permturnaroundunit is not null then
             vPromiseddate := FUN_U5GETSPBKPIDAY(ctr.ctr_org,vCalGroup,vFailure,spb.spb_permfixturnaround,spb.spb_permturnaroundunit);
          end if;
        end if;
        
        update r5contactrecords
        set    ctr_udfdate03 = vUdfdate03,
               ctr_temppromiseddate = vTemppromiseddate,
               ctr_udfdate04 = vUdfdate04,
               ctr_promiseddate = vPromiseddate
        where  ctr_code = ctr.ctr_code
        and    (nvl(ctr_udfdate03,to_date('1900-01-01','YYYY-MM-DD')) <>  nvl(vUdfdate03,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(ctr_temppromiseddate,to_date('1900-01-01','YYYY-MM-DD')) <>  nvl(vTemppromiseddate,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(ctr_udfdate04,to_date('1900-01-01','YYYY-MM-DD')) <>  nvl(vUdfdate04,to_date('1900-01-01','YYYY-MM-DD'))
            or nvl(ctr_promiseddate,to_date('1900-01-01','YYYY-MM-DD')) <>  nvl(vPromiseddate,to_date('1900-01-01','YYYY-MM-DD'))
            );
         /*insert into cxu_test(tst_proc,tst_step,tst_desc) 
         values ('CTR_INS_20',s5trans.nextval,'Update KPI Time for KPI '|| spb.spb_code);*/
     exception when no_data_found then
        vCalGroup := null;
     end;
     
  end if; --End to calculate KIP Time
  
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
/*when others then
    RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5contactrecords/Post Insert/10/'||substr(SQLERRM, 1, 500));*/
end;
