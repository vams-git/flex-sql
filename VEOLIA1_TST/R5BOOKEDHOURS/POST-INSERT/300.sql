declare 
  boo             r5bookedhours%rowtype;
  
  vOrder          r5orderlines.orl_order%type;
  vOrdLine        r5orderlines.orl_ordline%type;
  vOrg            r5orderlines.orl_order_org%type;
  vType           varchar2(10);
  
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
   --vInfTime := o7gttime(vOrg);
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

 
PROCEDURE insert_xmltranstatus
AS
BEGIN
  insert into r5xmltranstatus
  (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,XTS_KEYFLDDATE1,xts_org,xts_orig_messageid)
  values
  (vXMLSeqNum,sysdate,'PORECEIVESERVICE','R5BOOKEDHOURS',boo.boo_event,boo.boo_act,boo.boo_acd,NULL,boo.boo_entered,vOrg,o7sess.get_messageid());
END;
 
begin
  select * into boo from r5bookedhours where rowid=:rowid;
  if boo.boo_person is null and boo.boo_misc = '-' and boo.boo_routeparent is null  then
   /*****1. Export to ION****/
    vTrans := 'BOOK';
    vSource := 'EAM';
    vDestination := 'SAP';
    
    --select decode(boo.boo_correction,'-','RECV','RETN') into vType from dual;
    if nvl(boo.boo_orighours,boo.boo_hours) > 0 then
      vType := 'RECV';
    else
      vType := 'RETN';
    end if;
    begin
      if boo.boo_order is null then
        select act_order,act_ordline,act_order_org
        into vOrder,vOrdLine,vOrg
        from r5activities
        where act_event = boo.boo_event and act_act = boo.boo_act;
      else
         vOrder := boo.boo_order;
         vOrdLine := boo.boo_ordline;
         vOrg := boo.boo_order_org;
      end if;
    exception when no_data_found then 
      vOrder := null;
      vOrdLine := null;
    end;
    
    begin
      select x.xts_seqnum into vXMLSeqNum
      from r5xmltranstatus x
      where xts_trantype = 'PORECEIVESERVICE' and xts_table ='R5BOOKEDHOURS' 
      and xts_keyfld1 = boo.boo_event and nvl(xts_keyfld2,' ') = boo.boo_act
      and nvl(xts_keyfld3,' ') = boo.boo_acd;
      vCount := 1;
    exception when no_data_found then
      vCount := 0;
      vXMLSeqNum := s5xmltranstatus.nextval;
       --Insert into XMLTRANSTATUS
      insert_xmltranstatus;
    end;
    
    vKeyFld1:=boo.boo_code;
    vKeyFld2:=vType;
    vKeyFld3:=vOrder||'#'||boo.boo_event||'#'||boo.boo_act;
    vKeyFld4:=vOrg;
    vKeyFld5:= boo.boo_acd;

    select count(1) into vCount
    from u5ionmonitor
    where ion_source = 'EAM' and ion_destination = 'SAP'
    and   ion_trans = vTrans
    and   nvl(ion_keyfld1,' ') = nvl(vKeyFld1,' ') and nvl(ion_keyfld2,' ') = nvl(vKeyFld2,' ')
    and   nvl(ion_keyfld3,' ') = nvl(vKeyFld3,' ') and nvl(ion_keyfld4,' ') = nvl(vKeyFld4,' ')
    and   ion_xmlseqno = vXMLSeqNum;
     
     if vCount = 0 then
        insert_monitor('EAM','SAP',vTrans,vKeyFld1,vKeyFld2,vKeyFld3,vKeyFld4,vKeyFld5,vOrg);
     end if;
     
     --Update last receipt date on PO line
     if vType = 'RECV' then
        update r5orderlines
        set orl_udfdate01 = o7gttime(vOrg)
        where orl_order = vOrder and orl_order_org = vOrg and orl_ordline = vOrdLine;
     end if;
      
    --U5SAPUTIL.insert_montior(vSource,vDestination,vTrans,boo.boo_code,vType,vOrder||'#'||boo.boo_event,null,vIONTransID);
    --vxml := u5sapionexp.GET_BOOK(boo.boo_code,vIONTransID);
    --U5SAPUTIL.update_monitor_data(vIONTransID,vxml); 
  end if;
exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/300'  ||SQLCODE || SQLERRM) ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;