declare
   rec_adddetails    r5addetails%rowtype;
   evt               r5events%rowtype;
   vXMLSeqNum        r5xmltranstatus.xts_seqnum%type;
   vCnt              number;
   vOrg              r5organization.org_code%type;
   vSource           VARCHAR2(80);
   vDestination      VARCHAR2(80);
   vTrans            VARCHAR2(30);
   vKeyFld1          VARCHAR2(80);
   vKeyFld2          VARCHAR2(80);
   vKeyFld3          VARCHAR2(80);
   vKeyFld4          VARCHAR2(80);
   vKeyFld5          VARCHAR2(80);
   

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
vInfTime      date; 

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
    select * into rec_adddetails
    from r5addetails
    where rowid=:rowid; 
    
   if rec_adddetails.add_rentity = 'EVNT' and rec_adddetails.add_type ='+' then 
       select * into evt from r5events e where evt_code = rec_adddetails.add_code and evt_org = 'QTN'
       and e.evt_createdby = 'MIGRATION' and e.evt_udfchar28 is not null;
       
        vSource := 'EAM';
        vDestination := evt.evt_org;
        vTrans := 'UPDATEREQ';
        
        vKeyFld1 := evt.evt_contactrecord;
        vKeyFld2 := evt.evt_status;
        vKeyFld3 := evt.evt_udfchar28;
        vKeyFld4 := evt.evt_code;
        begin
          select x.xts_seqnum into vXMLSeqNum
          from r5xmltranstatus x
          where xts_trantype = 'SYNCMAINTORDER' and xts_table ='R5EVENTS' 
          and xts_keyfld1 = rec_adddetails.add_code;
          vCnt := 1;
        exception when no_data_found then
          vCnt := 0;
          vXMLSeqNum := s5xmltranstatus.nextval;
          insert into r5xmltranstatus
          (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
          values
          (vXMLSeqNum,sysdate,'SYNCMAINTORDER','R5EVENTS',rec_adddetails.add_code,
          'R',null,null,vOrg,o7sess.get_messageid());
        end;
                
        select count(1) into vCnt
        from u5ionmonitor
        where ion_source = vSource and ion_destination = vDestination
        and   ion_trans = vTrans
        and   nvl(ion_keyfld1,' ') = nvl(vKeyFld1,' ') and nvl(ion_keyfld2,' ') = nvl(vKeyFld2,' ')
        and   nvl(ion_keyfld3,' ') = nvl(vKeyFld3,' ') and nvl(ion_keyfld4,' ') = nvl(vKeyFld4,' ')
        and   ion_xmlseqno = vXMLSeqNum;
             
       if vCnt = 0 then
          insert_monitor(vSource,vDestination,vTrans,vKeyFld1,vKeyFld2,vKeyFld3,vKeyFld4,vKeyFld5,evt.evt_org);
       end if;
   end if;
    
exception 
  when no_data_found then 
    null;
  when others then
          RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/70/'||substr(SQLERRM, 1, 500)) ;
end;