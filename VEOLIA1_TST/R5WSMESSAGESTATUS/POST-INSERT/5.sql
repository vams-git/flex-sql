declare 
  wss             r5wsmessagestatus%rowtype;
  vFlag           varchar2(1);
  vTrandID        number;
  chk             varchar2(3);
  vSource         varchar2(10);
  vDestination    varchar2(10);
  vTrans          varchar2(10);
  
  
      
begin
  select * into wss from r5wsmessagestatus ws where rowid=:rowid;
  vFlag := 'N';
  --for sap inbound
  --UNDEFINED->NEW->ERROR/PROCESSED-->
  if wss.wss_type in ('BI') then
     if UPPER(wss.wss_document) in ('SYNCCODEDEFINITION','SYNCITEMMASTER','PROCESSITEMMASTER','SYNCSUPPLIERPARTYMASTER',
       'SYNCREQUISITION','SYNCPURCHASEORDER',
       'PROCESSSUPPLIERINVOICE','SYNCASSETTRACKINGDATA',
       'SYNCASSETMASTER','SYNCASSETMETERREADING',
	   'PROCESSCUSTOMERCALL') then                     
        vFlag := 'Y';
     end if;
  end if;
  
  if vFlag = 'Y' then
     r5o7.o7maxseq(vTrandID, 'INTERFACE', '1', chk);
     insert into U5IONMONITOR
    (ION_TRANSID,ION_SOURCE,ION_DESTINATION,ION_TRANS,
     ION_WSSCODE,ION_MESSAGEID,ION_REQ_WSMMSG,ION_RSP_WSMMSG,
     ION_KEYFLD1,ION_KEYFLD2,ION_KEYFLD3,ION_DATA,
     ION_CREATE,ION_STATUS,ION_SENDEMAIL,UPDATECOUNT,CREATED,CREATEDBY)
     values
     (vTrandID,vSource,vDestination,vTrans,
      wss.wss_code,wss.wss_correlationid,wss.wss_req_msgind,wss.wss_rsp_msgind,
      null,null,null,null,
      sysdate,'New','-',0,trunc(sysdate),'R5'
     );
  end if;
 -- null;
exception when others then 
  null;
end;
