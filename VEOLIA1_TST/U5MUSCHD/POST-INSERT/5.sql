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
  and   pmt_parameter in ('R5_START','R5_END','START','END');
  --and   pmt_datatype in ('DF','DT'); 
begin
  select * into msh from u5muschd where rowid=:rowid;

   
  update u5muschd set MSH_MAAPK = null where rowid=:rowid and MSH_MAAPK is not null;
  
 
 
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
end;