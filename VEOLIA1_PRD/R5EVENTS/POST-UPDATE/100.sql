declare 
 evt             r5events%rowtype;
 vLocale         r5organization.org_locale%type;
 vNewValue       r5audvalues.ava_to%type;
 vOldValue       r5audvalues.ava_from%type;
 vTimeDiff       number;
 vIsUpdated      VARCHAR2(1);
 vKPIDateDesc      VARCHAR2(80);
 vComment          VARCHAR2(4000);
 vAddLine          R5ADDETAILS.ADD_LINE%TYPE;
 vCount            number;
 
PROCEDURE AuditKPIChanges
(vColumnName in varchar2) AS

BEGIN
  vIsUpdated := 'N';
  begin
      
      select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
      from (
      select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5EVENTS' and aat_column = vColumnName
      and   ava_table = 'R5EVENTS' 
      and   ava_primaryid = evt.evt_code
      --and  ava_updated = '+'
      --and ava_inserted ='+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 1
      order by ava_changed desc
      ) where rownum <= 1;   
      vIsUpdated := 'Y';
      
      if vNewValue is not null then
          vNewValue := to_char(to_date(vNewValue,'YYYY-MM-DD HH24:mi'),'MON-DD-YYYY HH24:mi');
      end if;
      if vOldValue is not null then
          vOldValue := to_char(to_date(vOldValue,'YYYY-MM-DD HH24:mi'),'MON-DD-YYYY HH24:mi');
      end if;
      
      if vColumnName = 'EVT_UDFDATE05' then
         vKPIDateDesc := 'Respond By Date - KPI changed from ';
      elsif vColumnName = 'EVT_TFPROMISEDATE' then
         vKPIDateDesc := 'First Repair Date - KPI changed from ';
      elsif vColumnName = 'EVT_TFDATECOMPLETED' then
         vKPIDateDesc := 'Restoration Date - KPI changed from ';
      elsif vColumnName = 'EVT_PFPROMISEDATE' then
         vKPIDateDesc := 'Date Completed - KPI changed from ';
      end if;
      
      if evt.evt_udfchkbox03 = '-' then
         update r5events set evt_udfchkbox03 = '+' where evt_code = evt.evt_code;
      end if;
      
       vComment:= vKPIDateDesc || vOldValue ||' to '|| vNewValue
       ||' by '||r5o7.o7get_desc('EN','USER',o7sess.cur_user,'','');
       select count(1) into vCount from
      (select add_line,
       R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line) as add_text,
       add_created
       from r5addetails
       where add_entity='EVNT' and add_code= evt.evt_code
       and   abs(o7gttime(evt.evt_org) - add_created) * 24 * 60 * 60 < 2)
       where add_text like vComment;
       if vCount = 0 then
          select nvl(max(add_line),0) + 10 into vAddLine
          from r5addetails where add_entity='EVNT' and add_code = evt.evt_code;
          insert into r5addetails
          (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
          values
          ('EVNT','EVNT','*','*',evt.evt_code,'EN',vAddLine,'+',vComment,o7gttime(evt.evt_org));
      end if;
   exception when no_data_found then 
      vNewValue := null;
      vOldValue := null;
      vKPIDateDesc := null;
      vIsUpdated := 'N';
   end;  
  
END AuditKPIChanges; 
   
 
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
     select org_locale into vLocale from r5organization where org_code = evt.evt_org;
     if vLocale in ('NZ') then
        begin
            select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
            from (
            select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
            from r5audvalues,r5audattribs
            where ava_table = aat_table and ava_attribute = aat_code
            and   aat_table = 'R5EVENTS' and aat_column in ('EVT_SERVICEPROBLEM')
            and   ava_table = 'R5EVENTS' 
            and   ava_primaryid = evt.evt_code
            --and  ava_updated = '+'
            --and ava_inserted ='+'
            and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
            order by ava_changed desc
            ) where rownum <= 1;   
            return;
         exception when no_data_found then 
            null;
         end;  
         AuditKPIChanges('EVT_UDFDATE05');
         AuditKPIChanges('EVT_TFPROMISEDATE');
         AuditKPIChanges('EVT_TFDATECOMPLETED');
         if evt.evt_Status not in ('48MR') then
            AuditKPIChanges('EVT_PFPROMISEDATE');
         end if;
         
         if evt.evt_Status = ('48MR') then
           begin
              select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
              from (
              select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
              from r5audvalues,r5audattribs
              where ava_table = aat_table and ava_attribute = aat_code
              and   aat_table = 'R5EVENTS' and aat_column in ('EVT_STATUS')
              and   ava_table = 'R5EVENTS' 
              and   ava_primaryid = evt.evt_code
              and   ava_to = '48MR'
              --and  ava_updated = '+'
              --and ava_inserted ='+'
              and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
              order by ava_changed desc
              ) where rownum <= 1; 
              return;  
           exception when no_data_found then 
              null;
           end;  
           AuditKPIChanges('EVT_PFPROMISEDATE');
         end if;
         
     end if;--vLocale in ('NZ')
  end if;   
 

exception 
when no_data_found then
     return;  
WHEN others THEN 
    RAISE_APPLICATION_ERROR ( -20003,'Error in Flex/R5EVENTS/100/Update') ; 
end;