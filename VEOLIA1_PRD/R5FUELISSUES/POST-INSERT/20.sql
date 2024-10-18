declare 
  fli             r5fuelissues%rowtype;
  vDepClass       r5depots.dep_class%type;
  
  vFliGLCode      r5fuels.fue_udfchar01%type;
  vDepGLCode      r5depots.dep_udfchar02%type;
  ICOSTCENTER     R5ACCOUNTDETAIL.ACD_SEGMENT1%TYPE := NULL;
  IWBS            R5ACCOUNTDETAIL.ACD_SEGMENT2%TYPE := NULL;
  IPROFITCENTER   R5ACCOUNTDETAIL.ACD_SEGMENT3%TYPE := NULL;
  IGLCODE         R5ACCOUNTDETAIL.ACD_SEGMENT4%TYPE;   
  IDocDate        Date;
  IPstDate        Date;
  IORGCODE        r5organization.org_code%type;
  IOBJDESC        r5objects.obj_desc%type;
  ISDEPCOMPANYCODE   r5organization.org_udfchar09%type;                               
  
  vErrMsg          VARCHAR2(300);
  err_val          exception;
  
  
begin
 select * into fli from r5fuelissues where rowid=:rowid;
 select dep_class into vDepClass from r5depots where dep_code = fli.fli_depot;
 select nvl(fue_udfchar01,'51311200') into vFliGLCode from r5fuels where fue_code = fli.fli_fuel;
 
 if vDepClass not in ('GIF') then
   --if fli.fli_price > 0 then
       if fli.fli_vehicle is not null then                
         SELECT SUBSTR(OBJ_COSTCODE,INSTR(OBJ_COSTCODE,'-') + 1),OBJ_DESC
         INTO   IWBS,IOBJDESC
         FROM   r5objects where obj_code = fli.fli_vehicle and obj_org = fli.fli_vehicle_org;
       end if;
       
       if fli.fli_depot is not null then
          select DEP_ORG,SUBSTR(DEP_UDFCHAR26,1,INSTR(DEP_UDFCHAR26, '-') - 1),DEP_UDFCHAR26,
          CASE WHEN DEP_CLASS = 'CRD' then nvl(DEP_UDFCHAR02,'20243100') ELSE nvl(DEP_UDFCHAR02,'16219010') END as vDepGLCode   
          into IORGCODE,ISDEPCOMPANYCODE,IPROFITCENTER,vDepGLCode
          from r5depots d
          where d.dep_code = fli.fli_depot and d.dep_org = fli.fli_depot_org;
       end if;
       
       --SAP Doc Date, Fuel Issue Date For CRD, use 1st date of week
       IDocDate := trunc(fli.fli_date);
       if vDepClass in ('CRD') then 
          select trunc(fli.fli_date,'IW') into IDocDate from dual;
       end if;
       
       if IWBS is not null and IPROFITCENTER is not null then
          update r5fuelissues set
          fli_udfchar01 = IWBS, --WBS
          fli_udfchar02 = IPROFITCENTER,  --PROF
          fli_udfchar03 = ISDEPCOMPANYCODE,    --COMPCODE
          fli_udfchar04 = IOBJDESC,    --OBJDESC
          fli_udfchar05 = vDepGLCode,--DEPGL
          fli_udfchar06 = vFliGLCode,--FUEGL
          fli_udfdate01 = IDocDate,    --Document Date
          fli_udfchkbox01 ='-'
          where rowid=:rowid;
          
      end if; --if IWBS is not null and IPROFITCENTER is not null then

    --end if;
  end if; --dep_class not in ('GIF')

exception
when err_val then
   RAISE_APPLICATION_ERROR (-20003,vErrMsg) ;   
when others then
   RAISE_APPLICATION_ERROR (-20003,'Error in Flex r5fuelissues/Post Insert/10/'||substr(SQLERRM, 1, 500)) ;   
end;