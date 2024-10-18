declare 
  evt           r5events%rowtype;
  --ctr           r5contactrecords%rowtype;
  vNewStatus    r5events.evt_status%type;
  vOldStatus    r5events.evt_status%type;
  vNewUDFCHAR24 r5events.evt_udfchar24%type;
  vOldUDFCHAR24 r5events.evt_udfchar24%type;
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
  (vXMLSeqNum,sysdate,'SYNCMAINTORDER','R5EVENTS',evt.evt_code,
  CASE WHEN evt.evt_interface IS NULL THEN 'A' ELSE 'R' END,null,null,evt.evt_org,o7sess.get_messageid());
END;

PROCEDURE insert_monitor
(
 iSource       in varchar2,
 iDestination  in varchar2,
 iTrans        in varchar2,
 iKeyfld1      in varchar2,
 iKeyfld2      in varchar2,
 iKeyfld3      in varchar2,
 iKeyfld4      in varchar2,
 iKeyfld5      in varchar2,
 iOrg          in varchar2
)  AS

chk           VARCHAR2(3);
vTransID      r5interface.int_transid%type;

BEGIN
   --vInfTime := o7gttime(evt.evt_org);
   vInfTime := sysdate;

   r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk);
   insert into U5IONMONITOR
  (ION_TRANSID,ION_SOURCE,ION_DESTINATION,ION_TRANS,ION_REF,ion_xmlseqno,
   ION_ORG,ION_KEYFLD1,ION_KEYFLD2,ION_KEYFLD3,ION_KEYFLD4,ION_KEYFLD5,ION_DATA,
   ION_CREATE,ION_STATUS,ION_SENDEMAIL,UPDATECOUNT,CREATED,CREATEDBY)
   values
   (vTransID,iSource,iDestination,iTrans,null,vXMLSeqNum,
   iOrg,iKeyfld1,iKeyfld2,iKeyfld3,iKeyfld4,iKeyfld5,null,
   vInfTime,'New','-',0,trunc(vInfTime),O7SESS.cur_user
   );

END insert_monitor;

begin
    select * into evt from r5events where rowid=:rowid;--evt_code = '1005429161';--
     --Validate work order is generate from call center
    if evt.evt_org in ('QTN') and evt.evt_contactrecord is not null and evt.evt_sourcesystem in ('QLDC') then
     /*
      --Check is Status Update or UDFCHAR24 update?
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
        and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 3
        order by ava_changed desc
        ) where rownum <= 1;
      exception when no_data_found then 
        vNewStatus := null;
        --return;
      end;
      
      --return if it is not update on EVT_STATUS or EVT_UDFCHAR24
      if vNewStatus is null and vNewUDFCHAR24 is null then
         return;
      end if;*/

      vKeyFld1 := evt.evt_contactrecord;
      vKeyFld2 := evt.evt_status;
      vKeyFld3 := evt.evt_udfchar28;
      vKeyFld4 := evt.evt_code;
      --vKeyFld5 := ctr.ctr_udfchar10;
      
      vExpFlag := 'N';
      --if  evt.evt_org in ('QTN') and evt.evt_status in ('46MS','48MR','49MF','50SO','31DU') then 
            vSource := 'EAM';
            vDestination := evt.evt_org;
             /*if evt.evt_status ='50SO' then
                vTrans := 'JOBDATA';
             else
                vTrans := 'STATUSUPD';
             end if; */
             vTrans := 'UPDATEREQ';
              begin
                select x.xts_seqnum into vXMLSeqNum
                from r5xmltranstatus x
                where xts_trantype = 'SYNCMAINTORDER' and xts_table ='R5EVENTS' 
                and xts_keyfld1 = evt.evt_code;
                vCount := 1;
              exception when no_data_found then
                vCount := 0;
                 --Insert into XMLTRANSTATUS
                insert_xmltranstatus;
              end;
              
              select count(1) into vCount
              from u5ionmonitor
              where ion_source = vSource and ion_destination = vDestination
              and   ion_trans = vTrans
              and   nvl(ion_keyfld1,' ') = nvl(vKeyFld1,' ') and nvl(ion_keyfld2,' ') = nvl(vKeyFld2,' ')
              and   nvl(ion_keyfld3,' ') = nvl(vKeyFld3,' ') and nvl(ion_keyfld4,' ') = nvl(vKeyFld4,' ')
              and   ion_xmlseqno = vXMLSeqNum;
     
             if vCount = 0 then
                insert_monitor(vSource,vDestination,vTrans,vKeyFld1,vKeyFld2,vKeyFld3,vKeyFld4,vKeyFld5,evt.evt_org);
             end if;

      --end if;
   end if;
end;