declare 
 ord              r5orders%rowtype;
 vCount           number;
 vNewValue        r5audvalues.ava_to%type;
 vOldValue        r5audvalues.ava_to%type;
 vTimeDiff        number;
 iErrMsg          varchar2(400);
 err_val          exception;
 
 vAddComm     varchar2(80);
 vComment         varchar2(4000);
 vLine            number;
 
  
cursor cur_evt(vOrg varchar2,vOrd varchar2) is 
select distinct orl_event 
from r5orderlines 
where orl_order_org = vOrg and orl_order = vOrd
and   orl_event is not null;
 
 
begin
  select * into ord from r5orders where rowid=:rowid;
  if ord.ord_udfchar29 is not null and ord.ord_sourcesystem in ('SAP') then
    
    begin
      select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
      from (
      select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5ORDERS' and aat_column = 'ORD_STATUS'
      and   ava_table = 'R5ORDERS' 
      and   ava_primaryid = ord.ord_code
      and   ava_secondaryid = ord.ord_org
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
      order by ava_changed desc
      ) where rownum <= 1;
    exception when no_data_found then 
      vNewValue := null;
      return;
    end;
    
    if vOldValue = 'U' and vNewValue = 'A' then
        begin
           select 
           dbms_lob.substr(TO_CLOB(
               R5REP.TRIMHTML(add_code,add_entity,add_type,add_lang,add_line) 
               ),3500,1)
           into vComment
           from r5addetails
           where add_entity ='PORD' 
           and add_code= ord.ord_code||'#'||ord.ord_org
           and add_lang ='EN'
           and rownum <=1;
         exception when no_data_found then
           vComment := null;
         end;
         
         if vComment is not null then
           vLine:=0;
           begin
            select nvl(max(add_line),0) into vLine
            from r5addetails
            where add_entity ='REQ' and add_code = ord.ord_udfchar29
            and add_lang ='EN';
           exception when no_data_found then
              vLine:=0;
           end;
           vLine:=vLine+10;
           insert into r5addetails
           (add_entity,add_rentity,add_type,add_rtype,add_code,
           add_lang,add_line,add_print,add_text,add_created,add_user)
           values
           ('REQ','REQ','*','*',ord.ord_udfchar29,
           'EN',vLine,'+',vComment,o7gttime(ord.ord_org),O7SESS.cur_user);
         end if; -- if vComment is not null then
         
         --Insert order comment
         begin
            select opa_desc into vAddComm from r5organizationoptions where opa_code = 'PURLOGW' and opa_org = ord.ord_org;
         exception when no_data_found THEN
            vAddComm := 'NO';
         end;
         if vAddComm = 'YES' then
           vComment :=  'PO #' || ord.ord_code || ' ' || ord.ord_desc || ' has been created';
           for rec_evt in cur_evt(ord.ord_org,ord.ord_code) loop
               select nvl(max(add_line),0) + 10 into vLine
               from r5addetails where add_entity = 'EVNT' and add_code = rec_evt.orl_event;
               insert into r5addetails
               (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
               values
               ('EVNT','EVNT','*','*',rec_evt.orl_event,'EN',vLine,'+',vComment,o7gttime(ord.ord_org));
           end loop;
         end if;
     end if; --vOldValue = 'U' and vNewValue = 'A' 
   
   
     
  end if;
  
 
  

exception 
   when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
   when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orders/Update/40/' ||SQLCODE || SQLERRM) ;
end;
 