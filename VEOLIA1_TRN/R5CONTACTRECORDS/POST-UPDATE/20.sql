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
  --This is post UPDATE on call center
  select * into ctr from r5contactrecords where rowid=:rowid;
  --Record get from WBOPDC, skip kpi calcuation, the time will get from interface.
  if ctr.ctr_udfchar30 = 'WBOPDC' then
     return;
  end if;
  --Initial Failure time and KPI Code.
  vFailure := ctr.ctr_udfdate02;
  vNewKPICode := ctr.ctr_serviceproblem;
  vNewKPIOrg := ctr.ctr_serviceproblem_org;
  --For QLDC Interface, set UDFDATE02 and Contract KPI Code
  begin
      select ava_to,ava_from into vNewKPICode,vOldKPICode from (
      select ava_to,ava_from 
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5CONTACTRECORDS' and aat_column = 'CTR_SERVICEPROBLEM'
      and   ava_table = 'R5CONTACTRECORDS' 
      and   ava_primaryid = ctr.ctr_code and ava_secondaryid = ctr.ctr_org
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
      order by ava_changed desc
      ) where rownum <= 1;
    exception when no_data_found then 
      vNewKPICode := null;
      return;
    end;
  
   /*insert into cxu_test(tst_proc,tst_step,tst_desc) 
   values ('CTR_UPD_20',s5trans.nextval,'CTR_SERVICEPROBLEM Change from ' || vOldKPICode ||' to '|| vNewKPICode);*/
  --Start to calculate KIP Time
  if vFailure is not null and vNewKPICode is not null and vNewKPICode not like '%DFLT-KPI%%' then
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
         values ('CTR_UPD_20',s5trans.nextval,'Update KPI Time for KPI '|| spb.spb_code);*/
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