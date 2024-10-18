declare 
  gli             r5glinterface%rowtype;
  vTrans          varchar2(4);
  vIONTransID     number;
  vSource         varchar2(10);
  vDestination    varchar2(10);
  
  vCount           number;
  vXMLSeqNum       r5xmltranstatus.xts_seqnum%type;
  vGLTransID       r5glinterface.gli_transid%type;
  vGLGroupID       r5xmltranstatus.xts_datafld1%type;

  vKeyFld1      VARCHAR2(80);
  vKeyFld2      VARCHAR2(80);
  vKeyFld3      VARCHAR2(80);
  vKeyFld4      VARCHAR2(80);
  vKeyFld5      VARCHAR2(80);
  vInfTime      date; 
  
PROCEDURE insert_monitor
(
 iSource       in varchar2,
 iDestination  in varchar2,
 iTrans        in varchar2,
 iKeyfld1      in varchar2,
 iKeyfld2      in varchar2,
 iKeyfld3      in varchar2,
 iKeyfld4      in varchar2,
 iKeyfld5      in varchar2
)  AS

chk           VARCHAR2(3);
vTransID      r5interface.int_transid%type;



BEGIN
   vInfTime := sysdate;
  
   r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk);
   insert into U5IONMONITOR
  (ION_TRANSID,ION_SOURCE,ION_DESTINATION,ION_TRANS,ION_REF,ion_xmlseqno,ION_TRANSGROUPID,
   ION_KEYFLD1,ION_KEYFLD2,ION_KEYFLD3,ION_KEYFLD4,ION_KEYFLD5,ION_DATA,
   ION_CREATE,ION_STATUS,ION_SENDEMAIL,UPDATECOUNT,CREATED,CREATEDBY)
   values
   (vTransID,iSource,iDestination,iTrans,null,vXMLSeqNum,vGLGroupID,
   iKeyfld1,iKeyfld2,iKeyfld3,iKeyfld4,iKeyfld5,null,
   vInfTime,'New','-',0,trunc(vInfTime),O7SESS.cur_user
   );

END insert_monitor;

begin
  select * into gli from r5glinterface where rowid=:rowid;
  select count(1) into vCount
  from r5glinterface 
  where gli_runid = gli.gli_runid;
  /*if vCount > 1 or 
  (gli.gli_process in ('GL-ISSUEFUELCRD','GL-ISSUEFUELCRD-C')) then*/
  --gnerate record in ION Interface monitor when Credit GL is inserted
  if gli.gli_enteredcr is not null then
     /*****1. Export to ION****/
    vTrans := 'GL';
    vSource := 'EAM';
    vDestination := 'SAP';
    
    begin
      select x.xts_keyfld1, x.xts_seqnum,x.xts_datafld1
      into vGLTransID,vXMLSeqNum,vGLGroupID
      from r5xmltranstatus x
      where xts_trantype = 'GLFEED' and xts_table ='R5GLINTERFACE'
      and   x.xts_keyfld2 = gli.gli_runid and x.xts_keyfld4 = gli.gli_process;
      vCount := 1;
    exception when no_data_found then
      vCount := 0;
      vXMLSeqNum := -1;
    end;
    /*begin
      select xth_seqnum into vXMLSeqNum from (
      select xth_seqnum
      from r5xmltranstatushist 
      where xth_trantype = 'POSTJOURNAL'
      and  xth_table =gli.gli_process
      order by xth_create desc
      ) where rownum <= 1;
      vCount := 1;
    exception when no_data_found then
      vCount := 0;
      vXMLSeqNum := -1;
    end;*/
    
    vKeyFld1 := gli.gli_runid;
    vKeyFld2 := gli.gli_process;
    vKeyFld3 := gli.gli_attribute2;
    vKeyFld5 := gli.gli_process || ':1:' ||  vGLTransID;
    
    insert_monitor(vSource,vDestination,vTrans,vKeyFld1,vKeyFld2,vKeyFld3,vKeyFld4,vKeyFld5);
  end if; 

exception 
when others then
null;
end;