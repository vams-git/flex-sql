declare 
  ucd   u5vucosd%rowtype;
  tss   u5tuschm%rowtype;
  
  v_CurrentDateTime   date;
  v_start_date	      date;
  v_end_date          date;
  v_next_date	      date;
  v_first_due         date;
  
  vCnt	              number;
  
  vErrMsg	          varchar2(400);
  vErr                exception; 
  
  
  cursor cur_tsksch is 
  select tsk_org,tsk_code,tsk_revision,
  tss_org,tss_task,tss_schid,tss_forecastdays,tss_freq_uom,tss_freq,
  tse_object,tse_object_org,tse_startdate,tse_due
  from r5tasks,u5tuschm tss,u5tusche tse
  where tsk_org = tss_org and tsk_code = tss_task
  and   tsk_org = tse_org and tsk_code = tse_task
  and   tss_schid = tse_schid 
  and   nvl(tss_notused,'-') = '-'
  and   tse_startdate is not null and trunc(tse_startdate) <= o7gttime(tsk_org);

  
begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 20 and ucd.ucd_recalccost = '+' then
     for rec_s in cur_tsksch loop
         v_CurrentDateTime := o7gttime(rec_s.tss_org);
		 v_start_date := trunc(v_CurrentDateTime); 
		 v_end_date := v_start_date + nvl(rec_s.tss_forecastdays,14);        

         --delete all the 
		 /*delete from u5tuschf
		 where tsf_org = rec_s.tsk_org and tsf_task = rec_s.tsk_code and tsf_taskrev = rec_s.tsk_revision 
		 and tsf_schid = rec_s.tss_schid and tsf_object = rec_s.tse_object and tsf_object_org = rec_s.tse_object_org
		 and tsf_target_date >= v_start_date;*/

		 
		 --initial next date
		 v_next_date := v_start_date;
		 vCnt := 1;
		 
		 vErrMsg := tss.tss_freq_uom;
			  raise vErr;
			  
         while v_next_date <= v_end_date or vCnt < 2 loop
		   vCnt:= vCnt+ 1;
           --Daily schedule 
           if tss.tss_freq_uom = 'DAYS' then
		      --reset v_next_date 
			  v_next_date := case when rec_s.tse_due is not null and rec_s.tse_due >= v_start_date then rec_s.tse_due + rec_s.tss_freq
                             else greatest(rec_s.tse_startdate,v_start_date) end;
			  
			  if v_next_date <= v_end_date and v_next_date >= v_start_date then
			      insert into u5tuschf
				  (tsf_org,tsf_task,tsf_taskrev,tsf_schid,tsf_object,tsf_object_org,
				  tsf_target,tsf_target_date,tsf_forecastdate)
				  values
				  (rec_s.tsk_org,rec_s.tsk_code,rec_s.tsk_revision,rec_s.tss_schid,rec_s.tse_object,rec_s.tse_object_org,
				   to_char(v_next_date,'YYYY-MM-DD'),v_next_date,v_CurrentDateTime);
				   if v_first_due is null then
				      v_first_due := v_next_date; -- Capture first due date
				   end if;
			  end if;
			  
			  --set for next date
			  v_next_date := v_next_date + rec_s.tss_freq; 
           end if;
         
           --Weekly schedule 
           if tss.tss_freq_uom = 'WEEKS' then
               null;
           end if;
           
           --Monthly schedule 
           if tss.tss_freq_uom = 'MONTHS' then
               null;
           end if;
           
           --Yearly schedule 
           if tss.tss_freq_uom = 'YEARS' then
              null;
           end if;
         
		    
         end loop;
		 --update next due date for equipment
		 update u5tusche set tse_due = v_first_due
		 where tse_task = rec_s.tsk_code  and tse_org = rec_s.tsk_org and tse_schid = rec_s.tss_schid
		 and tse_object = rec_s.tse_object and tse_object_org = rec_s.tse_object_org;
		 
     end loop;
	 update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;

EXCEPTION
WHEN vErr THEN
  RAISE_APPLICATION_ERROR ( -20003, vErrMsg); 
end;