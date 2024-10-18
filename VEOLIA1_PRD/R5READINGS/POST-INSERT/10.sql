declare 
  vCount number;
  rea   r5readings%rowtype;
  vMail r5mailtemplate.mat_code%type;
  
  cursor cur_awaitingMeterWO(iObject varchar2,iObjectOrg varchar2,iReading number) is 
   select evt.evt_code,evt.evt_object,evt.evt_ppm,evt_desc,
   evt.evt_udfchar04,evt.evt_udfchar08,evt.evt_udfchar12,evt.evt_udfchar16,
   evt_class,r5o7.o7get_desc('EN','UCOD',evt_status,'EVST', '') as evt_status,
   evt.evt_meterdue,to_char(evt.evt_target,'DD-MON-YYYY') as evt_target,to_char(evt.evt_schedend,'DD-MON-YYYY') as evt_schedend,
   evt.evt_createdby,obj.obj_udfchar15,obj.obj_udfchar16,obj.obj_udfchar12
   from r5ppms,r5ppmobjects,r5events evt,r5objects obj
   where ppm_code = ppo_ppm and ppm_revision = ppo_revision
   and   ppo_pk = evt_ppopk
   and   evt_object = obj_code and evt_object_org = obj_org
   and   evt_status ='A'
   and   abs(evt_meterdue - iReading) <= 50
   and   ppo_meterdue is not null
   and   ppo_object = iObject and ppo_object_org = iObjectOrg;
   
begin
  select * into rea from r5readings where rowid=:rowid;
  if rea.rea_object_org in ('RRM','SBW', 'WOO') then
     select count(1) into vCount
     from r5ppmobjects,r5events
     where ppo_pk = evt_ppopk
     and   evt_status ='A'
     and   abs(evt_meterdue - rea.rea_reading) <= 50
     and   ppo_meterdue is not null
     and   ppo_object = rea.rea_object and ppo_object_org = rea.rea_object_org
     and   ppo_metuom = rea.rea_uom;
  end if;
  
  if vCount> 0 then
     if rea.rea_object_org = 'RRM' then
        vMail := 'M-RRM-WO-PREBMPM';
     elsif  rea.rea_object_org = 'SBW' then 
        vMail := 'M-SBW-WO-PREBMPM';
     elsif  rea.rea_object_org = 'WOO' then 
        vMail := 'M-WOO-WO-PREBMPM';
     end if;

     begin
     for rec_wo in cur_awaitingMeterWO(rea.rea_object,rea.rea_object_org,rea.rea_reading) loop
         insert into r5mailevents
         (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
          MAE_PARAM1,
          MAE_PARAM2,
          MAE_PARAM3,
          MAE_PARAM4,
          MAE_PARAM5,
          MAE_PARAM6,
          MAE_PARAM7,
          MAE_PARAM8,
          MAE_PARAM9,
          MAE_PARAM10,--obj_udfchar16-TagCode
          MAE_PARAM11,--obj_udfchar12-Poistion dESC
          MAE_PARAM12,
          MAE_PARAM13,
          MAE_PARAM14,
          MAE_ATTRIBPK)
          VALUES
          (S5MAILEVENT.NEXTVAL,vMail,SYSDATE,'-','N',
           rec_wo.evt_createdby,
           rec_wo.evt_code,
           rec_wo.evt_desc,
           rec_wo.evt_object,
           rec_wo.evt_ppm,
           rec_wo.evt_class,
           rec_wo.evt_status,
           rec_wo.evt_udfchar04,
           rec_wo.evt_udfchar08,
           rec_wo.obj_udfchar16,
           rec_wo.obj_udfchar12,
           rec_wo.evt_meterdue,
           rec_wo.evt_target,
           rec_wo.evt_schedend,
           0
          );
     end loop;

    exception
      when no_data_found then
        null;
      when others then
        null;
     end;
  end if;
exception   
when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/R5READINGS/Insert/10') ;
end;