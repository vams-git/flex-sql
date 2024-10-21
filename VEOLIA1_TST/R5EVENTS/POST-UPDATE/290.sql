declare 
  evt               r5events%rowtype;
  vNewStatus        r5events.evt_status%type;
  vOldStatus        r5events.evt_status%type;
  vTimeDiff         number;
  vEmail            r5personnel.per_emailaddress%type;
  vUserEmail        r5users.usr_emailaddress%type;
  
  vCnt              number;
  vMailTemp         r5mailevents.mae_code%type;
  vPK               r5mailattribs.maa_pk%type;
  test_err          exception;
  iErrMsg           varchar2(400);   
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_jobtype not in ('MEC') and evt.evt_org IN ('TAS','RRM','VIC','WAR','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP','FCG') then
     if evt.evt_status in ('40PR') and evt.evt_person is not null then
         --check is evt_person is contract
         begin
           select per.per_emailaddress into vEmail
           from r5personnel per
           where per_code = evt.evt_person
           and   per_notused = '-' and per.per_emailaddress is not null
           and   instr(per.per_emailaddress,'@') > 0
           and   per_udfchkbox01 ='+' and per_udfchar03 ='LAB';
           vCnt := 1;
         exception when no_data_found then
           vCnt := 0;
         end;

         if vCnt > 0 then
             begin
                select ava_to,ava_from,timediff into vNewStatus,vOldStatus,vTimeDiff
                from (
                select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
                from r5audvalues,r5audattribs
                where ava_table = aat_table and ava_attribute = aat_code
                and   aat_table = 'R5EVENTS' and aat_column = 'EVT_STATUS'
                and   ava_table = 'R5EVENTS' 
                and   ava_primaryid = evt.evt_code
                and   ava_updated = '+'
                and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
                order by ava_changed desc
                ) where rownum <= 1;
             exception when no_data_found then 
                vNewStatus := null;
                return;
             end;
             if vOldStatus in ('15TV','25TP') then
               select usr_emailaddress into vUserEmail
               from r5users where usr_code = o7sess.cur_user;              
               if evt.evt_org = 'TAS' then
                  if evt.evt_mrc = 'TAS-700' then
                     vMailTemp := 'M-TAS-WO-CONT-N';
                  else
                     vMailTemp := 'M-TAS-WO-CONT-S';
                  end if;
                end if;
                if evt.evt_org = 'RRM' then
                   vMailTemp := 'M-RRM-WO-CONT-N';
                end if;
                if evt.evt_org = 'VIC' then
                   vMailTemp := 'M-VIC-WO-CONT-METR';
                end if;
                if evt.evt_org = 'WAU' then
                   vMailTemp := 'M-WAU-WO-CONT-S';
                end if;
                if evt.evt_org = 'NWA' then
                   vMailTemp := 'M-NWA-WO-CONT-S';
                end if;
                if evt.evt_org = 'WAR' then
                   vMailTemp := 'M-WAR-WO-CONT-S';
                end if;
                if evt.evt_org = 'SAU' then
                   vMailTemp := 'M-SAU-WO-CONT-S';
                end if;
                if evt.evt_org = 'NSW' then
                   vMailTemp := 'M-NSW-WO-CONT-S';
                end if;
                if evt.evt_org = 'QLD' then
                   vMailTemp := 'M-QLD-WO-CONT-S';
                end if;
                if evt.evt_org = 'NTE' then
                   vMailTemp := 'M-NTE-WO-CONT-S';
                end if;
                if evt.evt_org = 'NVE' then
                   vMailTemp := 'M-NVE-WO-CONT-S';
                end if;
                if evt.evt_org = 'NVP' then
                   vMailTemp := 'M-NVP-WO-CONT-S';
                end if;
                if evt.evt_org = 'NVW' then
                   vMailTemp := 'M-NVW-WO-CONT-S';
                end if;
                  --vMailTemp := 'M-TAS-WO-CONT';
                  select count(1) into vCnt from r5mailevents mae
                  where mae.mae_template = vMailTemp
                  and   mae.mae_rstatus ='N'
                  and   mae.mae_param2 = evt.evt_code;
                  --vCnt := 0;
                  if vCnt = 0 then
                    BEGIN
                      vPK := 0;
                      /*select a.maa_pk into vPK
                      from r5mailattribs a where a.maa_template = vMailTemp and a.maa_table ='R5EVENTS';*/
                      insert into r5mailevents
                      (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
                       MAE_PARAM1,--EVT_PERSO
                       MAE_PARAM2,--EVT_CODE
                       MAE_PARAM3,--EVT_DESC
                       MAE_PARAM4,--EVT_OBJECT
                       MAE_PARAM5,--EVT_LOCATION
                       MAE_PARAM6,--NEVT_CREATED
                       MAE_PARAM8,--EVT_UDFCHAR04 Site
                       MAE_PARAM9,-- EVT_UDFCHAR08 Unit
                       MAE_PARAM11,--EVT_UDFCHAR12 Poistion
                       MAE_PARAM12,--EVT_REQUESTSTART Poistion
                       MAE_PARAM13,--EVT_SCHEDEND
                       MAE_PARAM14,--EVT_PERSON
                       MAE_PARAM15,MAE_ATTRIBPK) 
                      values
                      (S5MAILEVENT.NEXTVAL,vMailTemp,SYSDATE,'-','N',
                       vEmail || ' ' || vUserEmail,--evt.evt_person,
                       evt.evt_code,
                       evt.evt_desc,
                       evt.evt_object,
                       evt.evt_location,
                       evt.evt_createdby,
                       evt.evt_udfchar04,
                       evt.evt_udfchar08,
                       evt.evt_udfchar12,
                       evt.evt_requeststart,
                       evt.evt_schedend,
                       evt.evt_person,
                       o7sess.cur_user,
                       vPK);
                     exception when no_data_found then
                       iErrMsg:= 'eMail is not configured';
                       raise test_err;
                     end;
                  end if;
             end if;
         end if;
     end if;
  end if;
  
exception 
 when test_err then 
   RAISE_APPLICATION_ERROR (-20003,'ERR/R5EVENTS/290/U - '||iErrMsg);  
 when others then       
   RAISE_APPLICATION_ERROR (-20001,'ERR/R5EVENTS/290/U - ');   
end;
