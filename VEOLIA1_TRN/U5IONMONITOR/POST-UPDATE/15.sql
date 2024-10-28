declare 
  ion           u5ionmonitor%rowtype;
  vXMLSeqNum    r5xmltranstatus.xts_seqnum%type;
  vInfTime      date; 
  vTransID      r5interface.int_transid%type;
  vErr          exception;
  vErrMsg       varchar2(400);
  
  vBooEvent     r5bookedhours.boo_event%type;
  vBooAct       r5bookedhours.boo_act%type;
  vBooAcd       r5bookedhours.boo_acd%type;
  vBooEntered   r5bookedhours.boo_entered%type;
  
  vEvtCode      r5events.evt_code%type;
  vEvtOrg       r5events.evt_org%type;
  vEvtInterface r5events.evt_interface%type;
  
  vRunID        r5glinterface.gli_runid%type;
  vEntryID      r5glinterface.gli_entryid%type;
 
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
 iORG          in varchar2,
 iOrigTransid  in number
)  AS

chk           VARCHAR2(3);


BEGIN
   r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk);
   insert into U5IONMONITOR
  (ION_TRANSID,ION_SOURCE,ION_DESTINATION,ION_TRANS,ION_REF,ion_xmlseqno,
   ION_ORG,ION_KEYFLD1,ION_KEYFLD2,ION_KEYFLD3,ION_KEYFLD4,ION_KEYFLD5,ION_DATA,
   ION_CREATE,ION_STATUS,ION_SENDEMAIL,UPDATECOUNT,CREATED,CREATEDBY)
   values
   (vTransID,iSource,iDestination,iTrans,null,vXMLSeqNum,
   iORG,iKeyfld1,iKeyfld2,iKeyfld3,iKeyfld4,iKeyfld5,null,
   vInfTime,'New','-',0,trunc(vInfTime),O7SESS.cur_user
   );

END insert_monitor;
begin
  --To Reprocess outbound by standard BOD
  --Reprocess-->Insert new record
  select * into ion from u5ionmonitor where rowid=:rowid;
  
  if nvl(ion.ion_reprocess,'-') = '+' and ion.ion_reprocessid is null then
     /*if ion.ion_status not in ('Failed') then
        vErrMsg := 'You only could reprocess Failed Message';
        raise vErr;
     end if;*/
     if ion.ion_source not in ('EAM') then
        vErrMsg := 'You only could reprocess EAM outbound Message';
        raise vErr;
     end if;
     if ion.Ion_Destination in ('EAM') then
        vErrMsg := 'You only could reprocess EAM outbound Message';
        raise vErr;
     end if;
     
     vInfTime:= sysdate;
     /*if ion.ion_org is not null then
        vInfTime := o7gttime(ion.ion_org);
     end if;*/
     vTransID := null;
     
     if ion.ion_source in ('EAM') and ion.ion_destination in ('SAP') then
        if ion.ion_trans = 'REQ' then
            --keyfld1-req_code; keyfld2-req_org;
            vXMLSeqNum := s5xmltranstatus.nextval;
            insert into r5xmltranstatus
            (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
            values
            (vXMLSeqNum,sysdate,'ADDREQUISTN','R5REQUISITIONS',ion.ion_keyfld1,ion.ion_keyfld2,NULL,NULL,ion.ion_keyfld2,o7sess.get_messageid());
            insert_monitor(ion.ion_source,ion.ion_destination,ion.ion_trans,ion.ion_keyfld1,ion.ion_keyfld2,ion.ion_keyfld3,ion.ion_keyfld4,ion.ion_keyfld5,ion.ion_org,ion.ion_transid);
        end if;
        if ion.ion_trans = 'PORL' then
            --keyfld1-ord_code; keyfld2-orl_ordline; keyfld3-orl_status; keyfld4-ord_org;
            vXMLSeqNum := s5xmltranstatus.nextval;
            insert into r5xmltranstatus
            (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
            values
            (vXMLSeqNum,sysdate,'CHANGEPO','R5ORDERS',ion.ion_keyfld1,ion.ion_keyfld4,NULL,NULL,ion.ion_keyfld4,o7sess.get_messageid());
            insert_monitor(ion.ion_source,ion.ion_destination,ion.ion_trans,ion.ion_keyfld1,ion.ion_keyfld2,ion.ion_keyfld3,ion.ion_keyfld4,ion.ion_keyfld5,ion.ion_org,ion.ion_transid);
        end if;
        if ion.ion_trans = 'TRAN' then
            --keyfld1-tra_code,--keyfld4-tra_org
            vXMLSeqNum := s5xmltranstatus.nextval;
            insert into r5xmltranstatus
            (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
            values
            (vXMLSeqNum,sysdate,'PORECEIVEPARTS','R5TRANSACTIONS',ion.ion_keyfld1,null,NULL,NULL,ion.ion_keyfld4,o7sess.get_messageid());
            insert_monitor(ion.ion_source,ion.ion_destination,ion.ion_trans,ion.ion_keyfld1,ion.ion_keyfld2,ion.ion_keyfld3,ion.ion_keyfld4,ion.ion_keyfld5,ion.ion_org,ion.ion_transid);
        end if;
        if ion.ion_trans = 'BOOK' then
           --keyfld1-tra_code,--keyfld4-tra_org
            begin
              select boo_event,boo_act,boo_acd,boo_entered
              into vBooEvent,vBooAct,vBooAcd,vBooEntered
              from r5bookedhours where boo_acd = ion.ion_keyfld5;
              
              vXMLSeqNum := s5xmltranstatus.nextval;
              insert into r5xmltranstatus
              (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,XTS_KEYFLDDATE1,xts_org,xts_orig_messageid)
              values
              (vXMLSeqNum,sysdate,'PORECEIVESERVICE','R5BOOKEDHOURS',vBooEvent,vBooAct,vBooAcd,NULL,vBooEntered,ion.ion_keyfld4,o7sess.get_messageid());
              insert_monitor(ion.ion_source,ion.ion_destination,ion.ion_trans,ion.ion_keyfld1,ion.ion_keyfld2,ion.ion_keyfld3,ion.ion_keyfld4,ion.ion_keyfld5,ion.ion_org,ion.ion_transid);
            exception when no_data_found then
              vErrMsg := 'Book Service is not found in EAM!';
              raise vErr;
            end;
        end if;
        /*if ion.ion_trans = 'GL' then
          select s5glrunid.nextval into vRunID from dual;
          select S5GLENTRYID.nextval into vEntryID from dual;
          
          insert into r5glinterface
          (gli_transid,gli_runid,gli_process,gli_group,gli_status,gli_setofbooksid,gli_accountingdate,gli_currencycode,gli_datecreated,gli_createdby,
          gli_actualflag,gli_userjecategoryname,gli_userjesourcename,
          gli_segment1,gli_segment2,gli_segment3,gli_segment4,gli_entereddr,gli_enteredcr,gli_transactiondate,gli_reference1,
          gli_attribute1,gli_attribute2,gli_attribute3,gli_attribute4,gli_glnomacct,gli_entryid,gli_org)
          select 
          s5glinterface.nextval,vRunID,glh_process,glh_group,'NEW',glh_setofbooksid,glh_accountingdate,glh_currencycode,glh_datecreated,glh_createdby,
          glh_actualflag,glh_userjecategoryname,glh_userjesourcename,
          glh_segment1,glh_segment2,glh_segment3,glh_segment4,glh_entereddr,glh_enteredcr,glh_transactiondate,glh_reference1,
          glh_attribute1,glh_attribute2,glh_attribute3,glh_attribute4,glh_glnomacct,vEntryID,glh_org
          from r5glinterfacehist
          where glh_runid = ion.ion_keyfld1;
          
          vTransID := vRunID;
        end if;*/
     end if;
     if ion.ion_source in ('EAM') and ion.ion_destination in ('QTN') then
        if ion.ion_trans in ('STATUSUPD','JOBDATA','UPDATEREQ') then
          begin
              select evt_code,evt_org,evt_interface
              into vEvtCode,vEvtOrg,vEvtInterface
              from r5events where evt_code = ion.ion_keyfld4;

              vXMLSeqNum := s5xmltranstatus.nextval;
              insert into r5xmltranstatus
              (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
              values
              (vXMLSeqNum,sysdate,'SYNCMAINTORDER','R5EVENTS',vEvtCode,
              CASE WHEN vEvtInterface IS NULL THEN 'A' ELSE 'R' END,null,null,vEvtOrg,o7sess.get_messageid());
              insert_monitor(ion.ion_source,ion.ion_destination,ion.ion_trans,ion.ion_keyfld1,ion.ion_keyfld2,ion.ion_keyfld3,ion.ion_keyfld4,ion.ion_keyfld5,ion.ion_org,ion.ion_transid);
            exception when no_data_found then
              vErrMsg := 'Work Order is not found in EAM!';
              raise vErr;
            end;
        end if;
     end if;
     
     if vTransID is not null then
        update u5ionmonitor
        set ION_REPROCESSID = vTransID
        where rowid =:rowid;
     end if;
       
  end if;
  
  
  
EXCEPTION
   WHEN vErr then
   RAISE_APPLICATION_ERROR ( -20003,vErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex U5IONMONITOR/Post Update/15/'||substr(SQLERRM, 1, 500)) ; 
end;
