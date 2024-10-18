declare 
  msh              u5muschd%rowtype;

  vCount           number;
  vDue             date;
  vDateValue       date;
  vStart	       date;
  vEnd             date;
  err_val          exception;
  iErrMsg          varchar2(500);
  
  cursor cur_msp(vReport varchar2) is
  select msh_template,msp_parameter,msp_month,msp_day,pmt_parameter
  from  r5repparms,u5muschp msp
  where pmt_function =vReport
  and   pmt_line = msp_reportparameter
  and   pmt_parameter in ('R5_START','R5_END','START','END','SEL_START','SEL_END');
  --and   pmt_datatype in ('DF','DT'); 
begin
  select * into msh from u5muschd where rowid=:rowid;

   
  for rec_msp in cur_msp(msh.Msh_Report) loop
      vDateValue := add_months(msh.msh_due,- rec_msp.msp_month) - rec_msp.msp_day;
  
      update u5muschp
       set    msp_datevalue = vDateValue,
              msp_value = to_char(vDateValue,'YYYY-MM-DD')
       where  msh_template = rec_msp.msh_template and msp_parameter = rec_msp.msp_parameter  
       and    nvl(msp_value,'1900-01-01') <> to_char(vDateValue,'YYYY-MM-DD')
	   and    msh_template = msh.msh_template;
	   

  end loop;
  
 
 
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
end;