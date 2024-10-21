declare 
  evt           r5events%rowtype;
  ctr           r5contactrecords%rowtype;
  vNewStatus    r5events.evt_status%type;
  vOldStatus    r5events.evt_status%type;
  vTimeDiff     number;
  vSource       VARCHAR2(80);
  vDestination  VARCHAR2(80);
  vTrans        VARCHAR2(30);
  vKeyFld1      VARCHAR2(80);
  vKeyFld2      VARCHAR2(80);
  vKeyFld3      VARCHAR2(80);
  vKeyFld4      VARCHAR2(80);
  vKeyFld5      VARCHAR2(80);
  vExpFlag      VARCHAR2(1);
  vCount        number;
  vInfTime      date; 
  vXMLSeqNum    r5xmltranstatus.xts_seqnum%type;

PROCEDURE insert_xmltranstatus
AS
BEGIN
  vXMLSeqNum := s5xmltranstatus.nextval;
  insert into r5xmltranstatus
  (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
  values
  (vXMLSeqNum,sysdate,'SYNCMAINTORDER','R5EVENTS',evt.evt_code,'A',vOldStatus,vNewStatus,evt.evt_org,o7sess.get_messageid());
END;


begin
    select * into evt from r5events where rowid=:rowid;--evt_code = '1005429161';--
    
    if evt.evt_type in ('JOB','PPM') and  evt.evt_parent is null and evt.evt_org 
      in --('WSL')
      ('CHB','DAN','QTN','RUA','STA','SWP','THC','VEO','WAN','WEW', 'WSL','DOC') 
      then
         --Check is Status Update?
        /*begin
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
        end;*/
           
         --check exsiting record   
         select count(1) into vCount
         from r5xmltranstatus 
         where xts_trantype = 'SYNCMAINTORDER' and xts_table ='R5EVENTS' and xts_keyfld1 = evt.evt_code;
         
         if vCount = 0 then
            insert_xmltranstatus;
         end if;
    end if;

end;
