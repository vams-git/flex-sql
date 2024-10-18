declare 
 req              r5requisitions%rowtype;
 vNewValue        r5audvalues.ava_to%type;
 vOldValue        r5audvalues.ava_from%type;
 vTimeDiff        number;
 
 vParUOM          r5requislines.rql_uom%type;
 vSAPPurUOM       r5requislines.rql_uom%type;
 vPurUom          r5requislines.rql_uom%type;
 vPurQty          r5requislines.rql_qty%type;
 vPurPrice        r5requislines.rql_price%type;
 vMultiply        r5requislines.Rql_Multiply%type;
 
 vAddComm         VARCHAR2(80);
 vComment         VARCHAR2(400);
 chk2             VARCHAR2(3);
 vLine            r5addetails.add_line%type;
 
 vCount           number;
 vXMLSeqNum       r5xmltranstatus.xts_seqnum%type;
 
  vSource       VARCHAR2(80);
  vDestination  VARCHAR2(80);
  vTrans        VARCHAR2(30);
  vKeyFld1      VARCHAR2(80);
  vKeyFld2      VARCHAR2(80);
  vKeyFld3      VARCHAR2(80);
  vKeyFld4      VARCHAR2(80);
  vKeyFld5      VARCHAR2(80);
  vInfTime      date; 
  
cursor cur_evt(vREQ varchar2) is 
select distinct rql_event 
from r5requislines 
where rql_req = vREQ
and rql_event is not null;
 
PROCEDURE insert_xmltranstatus
AS
BEGIN
  insert into r5xmltranstatus
  (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
  values
  (vXMLSeqNum,sysdate,'ADDREQUISTN','R5REQUISITIONS',req.req_code,req.req_org,NULL,NULL,req.req_org,o7sess.get_messageid());
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
 iORG          in varchar2
)  AS

chk           VARCHAR2(3);
vTransID      r5interface.int_transid%type;

BEGIN
   --vInfTime := o7gttime(iORG);
   vInfTime := sysdate;

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
  select * into req from r5requisitions where rowid=:rowid;
  
  -- Insert into XMLTRANS to export to ION
  begin
    select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
    from (
    select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
    from r5audvalues,r5audattribs
    where ava_table = aat_table and ava_attribute = aat_code
    and   aat_table = 'R5REQUISITIONS' and aat_column = 'REQ_STATUS'
    and   ava_table = 'R5REQUISITIONS' 
    and   ava_primaryid = req.req_code
    and   ava_updated = '+'
    and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 4
    order by ava_changed desc
    ) where rownum <= 1;
  exception when no_data_found then 
    vNewValue := null;
    return;
  end;
  
  if vNewValue in ('01SS','04RS') then
      update r5requisitions
      set req_enteredby = o7sess.cur_user,
      req_udfchar25 = (select usr_emailaddress  from r5users where usr_code = o7sess.cur_user),
      req_udfchar27 = r5o7.o7get_desc('EN','USER',o7sess.cur_user,'', '')--Enter By Name
      where rowid =:rowid
      and nvl(req.req_enteredby,' ') <> nvl(o7sess.cur_user,' ');
         
      begin
        select x.xts_seqnum into vXMLSeqNum
        from r5xmltranstatus x
        where xts_trantype = 'ADDREQUISTN' and xts_table ='R5REQUISITIONS' 
        and xts_keyfld1 = req.req_code and nvl(xts_keyfld2,' ') = req.req_org;
        vCount := 1;
      exception when no_data_found then
        vCount := 0;
        vXMLSeqNum := s5xmltranstatus.nextval;
         --Insert into XMLTRANSTATUS
        insert_xmltranstatus;
      end;
      
      select count(1) into vCount
      from u5ionmonitor
      where ion_source = 'EAM' and ion_destination = 'SAP'
      and   ion_trans = 'REQ'
      and   ion_keyfld1 = req.req_code and ion_org = req.req_org
      and   ion_xmlseqno = vXMLSeqNum;

      if vCount = 0 then
          insert_monitor('EAM','SAP','REQ',req.req_code,req.req_org,null,null,null,req.req_org);
      end if;
  end if;
  
  if vNewValue in ('01SS') then
     begin
         select opa_desc into vAddComm from r5organizationoptions where opa_code = 'PURLOGW' and opa_org = req.req_org;
     exception when no_data_found THEN
         vAddComm := 'NO';
     end;
     if vAddComm = 'YES' then
       vComment :=  'Requisition #' || req.req_code || ' ' || req.req_desc || ' has been submitted and is waiting approval';
       for rec_evt in cur_evt(req.req_code) loop
           select nvl(max(add_line),0) + 10 into vLine
           from r5addetails where add_entity = 'EVNT' and add_code = rec_evt.rql_event;
           insert into r5addetails
           (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
           values
           ('EVNT','EVNT','*','*',rec_evt.rql_event,'EN',vLine,'+',vComment,o7gttime(req.req_org));
       end loop;
     end if;
  end if;
  

  
exception 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Update/300/') ;
end;
 