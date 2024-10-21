-- Created on 27/11/2020 by CXU 
declare 
  -- Local variables here
  i integer;
begin
  -- Test statements here
  declare 
  tra                    r5transactions%rowtype;
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
  
  vReturnEmail  r5users.usr_emailaddress%type;
 
  
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
  --vInfTime := o7gttime(tra.tra_order_org);
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
  (xts_seqnum,xts_create,xts_trantype,xts_table,xts_keyfld1,xts_keyfld2,xts_keyfld3,xts_keyfld4,xts_org,xts_orig_messageid)
  values
  (vXMLSeqNum,sysdate,'PORECEIVEPARTS','R5TRANSACTIONS',tra.tra_code,null,NULL,NULL,tra.tra_org,o7sess.get_messageid());
END;


begin
  select * into tra from r5transactions where rowid=:rowid;
  if tra.tra_status ='A' and tra.tra_type in ('RECV','RETN') and tra.tra_routeparent is null and tra.tra_order is not null then
     /*****update email address line udfchar10****/
     --if tra.tra_auth is not null then
        begin
          select nvl(usr_emailaddress,usr_code) into vReturnEmail from r5users where usr_code = o7sess.cur_user
          and rownum<=1;
        exception when no_data_found then
          vReturnEmail:=tra.tra_auth;
        end;
        update r5translines
        set trl_udfchar10 = vReturnEmail
        where trl_trans = tra.tra_code
        and   nvl(trl_udfchar10,' ') <> nvl(vReturnEmail, ' ');
     --end if;
     
     /*****1. Export to ION****/
     vTrans := 'TRAN';
     vSource := 'EAM';
     vDestination := 'SAP';
     
     begin
      select x.xts_seqnum into vXMLSeqNum
      from r5xmltranstatus x
      where xts_trantype = 'PORECEIVEPARTS' and xts_table ='R5TRANSACTIONS' 
      and xts_keyfld1 = tra.tra_code and nvl(xts_keyfld2,' ') = tra.tra_org;
      vCount := 1;
    exception when no_data_found then
      vCount := 0;
      vXMLSeqNum := s5xmltranstatus.nextval;
       --Insert into XMLTRANSTATUS
      insert_xmltranstatus;
    end;
    
    vKeyFld1:=tra.tra_code;
    vKeyFld2:=tra.tra_type;
    vKeyFld4:=tra.tra_order_org;
    if tra.tra_type = 'RECV' then
      vKeyFld3 := tra.tra_order||'#'||tra.tra_dckcode;
    end if;
    if tra.tra_type = 'RETN' then
      vKeyFld3 := tra.tra_order;
    end if;
    
    select count(1) into vCount
    from u5ionmonitor
    where ion_source = 'EAM' and ion_destination = 'SAP'
    and   ion_trans = 'TRAN'
    and   nvl(ion_keyfld1,' ') = nvl(vKeyFld1,' ') and nvl(ion_keyfld2,' ') = nvl(vKeyFld2,' ')
    and   nvl(ion_keyfld3,' ') = nvl(vKeyFld3,' ') and nvl(ion_keyfld4,' ') = nvl(vKeyFld4,' ')
    and   ion_xmlseqno = vXMLSeqNum;
     
     if vCount = 0 then
        insert_monitor('EAM','SAP','TRAN',vKeyFld1,vKeyFld2,vKeyFld3,vKeyFld4,vKeyFld5,tra.tra_org);
     end if;
     
     --U5SAPUTIL.insert_montior(vSource,vDestination,vTrans,tra.tra_code,tra.tra_type,tra.tra_order,null,vIONTransID);
     /*if tra.tra_type in ('RECV') then
        vxml := u5sapionexp.GET_TRANSRECV(tra.tra_code,vIONTransID);
     else
        vxml := u5sapionexp.GET_TRANSRETN(tra.tra_code,vIONTransID);
     end if;
     U5SAPUTIL.update_monitor_data(vIONTransID,vxml); */
  end if;
  

exception when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSACTIONS/Post Update/300') ;
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;
end;

end;