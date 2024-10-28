declare 
 ucd         u5vucosd%rowtype;
 
 mae r5mailevents%rowtype;
 vValue varchar2(4000);
 vDate date;
 vCount number;
 
 cursor cur_h is 
 select msh_template,mat_mail,msh_due,msh_freq,msh_peroiduom,msh_maapk,msh_query,msh_recipient,msh_subject
 from u5muschd,r5mailtemplate where msh_template = mat_code and msh_status = 'A';
--and msh_template in ('K8-WAU-H716116850');

 cursor cur_l(vMail in varchar2) is 
 select msp_parameter,msp_reportparameter,pmt_parameter,pmt_datatype,msp_value,msp_month,msp_day
 from r5mailtemplate,r5repparms,u5muschp 
 where mat_code = vMail 
 and mat_report = pmt_function 
 and mat_code = msh_template 
 and pmt_line = msp_reportparameter
 union 
 select msp_parameter,msp_reportparameter,null,null,msp_value,msp_month,msp_day
 from r5mailtemplate,u5muschp
 where mat_code = vMail 
 and mat_code = msh_template 
 and msp_reportparameter is null;
 
begin
 select * into ucd from u5vucosd where rowid=:rowid;
 if ucd.ucd_id = 5 and ucd.ucd_recalccost = '+' then
    for  rec_h in cur_h loop
    begin
         if trunc(rec_h.msh_due) <= trunc(sysdate) then
           --check query count is > 0
           vCount := 1;
           if rec_h.msh_query is not null then
              EXECUTE IMMEDIATE rec_h.msh_query INTO vCount;
           end if;
           
           begin
            if vCount > 0 then
              mae.mae_param1 := null;
              mae.mae_param2 := null;
              mae.mae_param3 := null;
              mae.mae_param4 := null;
              mae.mae_param5 := null;
              mae.mae_param6 := null;
              mae.mae_param7 := null;
              mae.mae_param8 := null;
              mae.mae_param9 := null;
              mae.mae_param10 := null;
              mae.mae_param11 := null;
              mae.mae_param12 := null;
              mae.mae_param13 := null;
              mae.mae_param14 := null;
              
              if rec_h.msh_recipient is not null then
                 mae.mae_param1 := rec_h.msh_recipient;
              end if;
              if rec_h.msh_subject is not null then
                 mae.mae_param2 := rec_h.msh_subject;
              end if;
              
              for rec_l in cur_l(rec_h.msh_template) loop 
                  vValue := rec_l.msp_value;
                  /*if rec_l.pmt_datatype in ('DF','DT') then
                     vDate := add_months(trunc(sysdate),nvl(rec_l.msl_month,0)) + nvl(rec_l.msl_day,0);
                     vValue := to_char(vDate,'YYYY-MM-DD');
                  end if;*/
                  if rec_l.msp_parameter = 1 then
                     mae.mae_param1 := vValue;
                  elsif rec_l.msp_parameter = 2 then
                    mae.mae_param2 := vValue;
                  elsif rec_l.msp_parameter = 3 then
                    mae.mae_param3 := vValue;
                  elsif rec_l.msp_parameter = 4 then
                    mae.mae_param4 := vValue;
                  elsif rec_l.msp_parameter = 5 then
                    mae.mae_param5 := vValue;
                  elsif rec_l.msp_parameter = 6 then
                    mae.mae_param6 := vValue;
                  elsif rec_l.msp_parameter = 7 then
                    mae.mae_param7 := vValue;
                  elsif rec_l.msp_parameter = 8 then
                    mae.mae_param8 := vValue;
                  elsif rec_l.msp_parameter = 9 then
                    mae.mae_param9 := vValue;
                  elsif rec_l.msp_parameter = 10 then
                    mae.mae_param10 := vValue;
                  elsif rec_l.msp_parameter = 11 then
                    mae.mae_param11 := vValue;
                  elsif rec_l.msp_parameter = 12 then
                    mae.mae_param12 := vValue;
                  elsif rec_l.msp_parameter = 13 then
                    mae.mae_param13 := vValue;
                  elsif rec_l.msp_parameter = 14 then
                    mae.mae_param14 := vValue;
                  end if;
              end loop;
              
             insert into r5mailevents(
             mae_template,mae_date,mae_send,mae_rstatus,mae_attribpk,mae_emailrecipient,mae_param15,
             mae_param1,mae_param2,mae_param3,mae_param4,mae_param5,mae_param6,mae_param7,
             mae_param8,mae_param9,mae_param10,mae_param11,mae_param12,mae_param13,mae_param14          
             )
             values (
             rec_h.msh_template,sysdate,'-','N',rec_h.msh_maapk,rec_h.mat_mail,o7sess.cur_user,
             mae.mae_param1,mae.mae_param2,mae.mae_param3,mae.mae_param4,mae.mae_param5,mae.mae_param6,mae.mae_param7,
             mae.mae_param8,mae.mae_param9,mae.mae_param10,mae.mae_param11,mae.mae_param12,mae.mae_param13,mae.mae_param14  
             );
           end if;

           update u5muschd set msh_due = 
           case when rec_h.msh_peroiduom = 'D' then rec_h.msh_due + rec_h.msh_freq
           when rec_h.msh_peroiduom = 'W' then rec_h.msh_due + rec_h.msh_freq*7
           when rec_h.msh_peroiduom = 'M' then add_months(rec_h.msh_due,rec_h.msh_freq)
           when rec_h.msh_peroiduom = 'Q' then add_months(rec_h.msh_due,3*rec_h.msh_freq) 
           when rec_h.msh_peroiduom = 'Y' then add_months(rec_h.msh_due,12*rec_h.msh_freq) end
           ,MSH_EXECDATE = SYSDATE,MSH_UPDATEDBY = O7SESS.CUR_USER
           where msh_template = rec_h.msh_template;
          exception when others then null; end;
         end if;
    exception when others then 
      null;
    end;
    end loop;
    update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
 end if;
end;
