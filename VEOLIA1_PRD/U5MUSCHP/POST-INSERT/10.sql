declare 
  msp              u5muschp%rowtype;
  vStatus          u5muschd.msh_status%type;
  vCount           number;
  vDue             date;
  vDateValue       date;
  vDesc            u5muschp.msp_value%type;
  err_val          exception;
  iErrMsg          varchar2(500);
begin
  select * into msp from u5muschp where rowid=:rowid;
  
  select msh_status into vStatus
  from u5muschd
  where msh_template =  msp.msh_template;
  /*if vStatus = 'A' then
     iErrMsg := 'Please change status before you moidfy the the parameter';
     raise err_val;
  end if;*/
  
  
  select count(1) into vCount
  from  r5repparms,u5muschd 
  where msh_template = msp.msh_template
  and   pmt_function = msh_report and pmt_line = msp.msp_reportparameter
  and   pmt_parameter in ('R5_START','R5_END','START','END','SEL_START','SEL_END');
  --and   pmt_datatype in ('DF','DT');

  if vCount > 0 then
     if msp.msp_month is null or msp.msp_day is null then
        iErrMsg := 'Report Parameter is Start Date/End Date, Please fill in month before and day before';
        raise err_val;
     end if;
     
     select msh_due, add_months(msh_due,- msp.msp_month) - msp.msp_day
     into vDue,vDateValue
     from u5muschd 
     where msh_template = msp.msh_template;
     --iErrMsg := vDateValue;
     --raise err_val;
     
     update u5muschp
     set    msp_datevalue = vDateValue,
              msp_value = to_char(vDateValue,'YYYY-MM-DD')
     where  rowid =:rowid
     and     nvl(msp_value,'1900-01-01') <> to_char(vDateValue,'YYYY-MM-DD');
  end if;
  
  if msp.msp_isdesc = '+' then
     if msp.msp_entity ='CST' then
       begin
         select cst_desc into vDesc from r5costcodes where cst_code = msp.msp_value;
         update u5muschp 
         set    msp_value =  vDesc
         where  rowid =:rowid
         and    nvl(msp_value,' ') <> nvl(vDesc,' ');
       exception when no_data_found then 
         null;
       end;
     end if;
  end if;
  
 
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
end;