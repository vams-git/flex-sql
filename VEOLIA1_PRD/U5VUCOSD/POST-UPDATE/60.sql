declare 
 cursor cur_ion is
 select * from u5ionmonitor where 
  ion_wsscode is not null
  and (
  ion_status in ('New') 
  or   
  (ion_status in ('Failed') and exists (select 1 from r5wsreqhist where 
  wsq_message = ion_wsscode and (sysdate - wsq_time) * 24 * 60 < 10 ))
  );
 
 cursor cur_task (inTask in varchar2)is
 select regexp_substr(inTask,'[^:]+', 1, level) as corr_text,level from dual
 connect by regexp_substr(inTask, '[^:]+', 1, level) is not null
 order by level asc;
 
 ucd         u5vucosd%rowtype;
 
 vMsgText       r5wsmessages.wsm_text%type;
 wss            r5wsmessagestatus%rowtype;
 vComponentID   varchar2(400);
 vTaskID        varchar2(400);
 vXMLQuery_ns   varchar2(400);
 vSenderPath    varchar2(400);
 vDataAreaPath  varchar2(400);
 vHeaderPath    varchar2(400);
 vLinePath      varchar2(400);
 
 vSource        varchar2(10);
 vDest          varchar2(10);
 vTrans         varchar2(80);
 vRefDoc        varchar2(80);
 vKeyFld1       varchar2(80);
 vKeyFld2       varchar2(80);
 vOrg           varchar2(15);
 vAssetID       varchar2(30);
 vKeyFld3       varchar2(80);
 vKeyFld4       varchar2(80);
 vUOM           varchar2(80);
 vReading       varchar2(80);
 vLenPre        number;
begin
 select * into ucd from u5vucosd where rowid=:rowid;
 if ucd.ucd_id = 6 and ucd.ucd_recalccost = '+' then
 
 vXMLQuery_ns := 'declare namespace soapenv = "http://schemas.xmlsoap.org/soap/envelope/"; (: :)  
                  declare namespace ns1  = "http://schema.infor.com/InforOAGIS/2"; (: :)';
 for rec_ion in cur_ion loop
     vSource := null;vDest := null;vTrans := null;vRefDoc:=null;vKeyFld1:=null;vKeyFld2:=null;vOrg:=null;
     begin
        select wsm_text into vMsgText from r5wsmessages where wsm_msgind = rec_ion.ion_req_wsmmsg;
        select * into wss from r5wsmessagestatus where wss_code = rec_ion.ion_wsscode;
        if wss.wss_req_status not in ('I') then
            vSenderPath := '/soapenv:Envelope/soapenv:Body/ns1:'||wss.wss_document||'/ns1:ApplicationArea/ns1:Sender/';
             --get Component ID
            select XMLQUERY (  
             vXMLQuery_ns ||vSenderPath ||'ns1:ComponentID/text()'
             PASSING XMLTYPE(vMsgText) 
            RETURNING CONTENT).getStringVal() into vComponentID
            from dual;
            select XMLQUERY (  
             vXMLQuery_ns ||vSenderPath ||'ns1:TaskID/text()'  
             PASSING XMLTYPE(vMsgText) 
            RETURNING CONTENT).getStringVal() into vTaskID
            from dual;
             --For SAP Inbound
            if vComponentID ='SAP' and vTaskID is not null then
               vSource:=vComponentID;
               vDest:='EAM';
               vTrans := null;
               vRefDoc := null;
               vKeyFld1 := null;
               vOrg := null;
               if instr(vTaskID,':') > 0 then
                 for rec_task in cur_task(vTaskID) loop
                   NULL;
                     if rec_task.level = 1 then
                        vTrans := rec_task.corr_text;
                     elsif rec_task.level = 2 then
                        vRefDoc  := rec_task.corr_text;
                     elsif rec_task.level = 3 then
                        vKeyFld1 := rec_task.corr_text;
                      elsif rec_task.level = 4 then
                        vOrg := rec_task.corr_text;
                     end if;
                 end loop;
                 
                 --get supplier
                 vKeyFld2 := null;
                 if vTrans = 'INV' then
                     vDataAreaPath := '/soapenv:Envelope/soapenv:Body/ns1:'||wss.wss_document||'/ns1:DataArea/';
                    select XMLQUERY (vXMLQuery_ns ||vDataAreaPath ||
                    'ns1:SupplierInvoice/ns1:SupplierInvoiceHeader/ns1:SupplierParty/ns1:PartyIDs/ns1:ID/text()'  
                    PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() into vKeyFld2 from dual;
                 end if;
                   
                 
                 --'MQST:C-Completed;F-Failed;I-In Progress;PF-Partially failed'
                 update u5ionmonitor i
                 set i.ion_source = vSource,
                     i.ion_destination = vDest,i.ion_trans = SUBSTR(vTrans,1,10), i.ion_ref = vRefDoc, 
                     i.ion_keyfld1 = vKeyFld1, i.ion_keyfld2 = vKeyFld2,
                     i.ion_org = vOrg,
                     i.ion_status = r5o7.o7get_desc('EN','UCOD', wss.wss_req_status,'MQST', ''),
                     i.ion_message = replace(wss.wss_req_message,chr(10),'')
                where i.ion_transid = rec_ion.ion_transid;
              end if;
          end if; 
        
        --For QTN Inbound
      if vComponentID ='QTN' and vTaskID is not null then
               vSource:=vComponentID;
               vDest:='EAM';
               if instr(vTaskID,':') > 0 then
                 for rec_task in cur_task(vTaskID) loop
                   NULL;
                     if rec_task.level = 1 then
                        vTrans := rec_task.corr_text;
                     elsif rec_task.level = 2 then
                        vRefDoc  := rec_task.corr_text;
                     end if;
                 end loop;
                 --'MQST:C-Completed;F-Failed;I-In Progress;PF-Partially failed'
                 update u5ionmonitor i
                 set i.ion_source = vSource,
                     i.ion_destination = vDest,i.ion_trans = SUBSTR(vTrans,1,10), i.ion_ref = vRefDoc, i.ion_keyfld1 = vRefDoc, i.ion_org = 'QTN',
                     i.ion_status = r5o7.o7get_desc('EN','UCOD', wss.wss_req_status,'MQST', ''),
                     i.ion_message = replace(wss.wss_req_message,chr(10),'')
                where i.ion_transid = rec_ion.ion_transid;
        /*if wss.wss_req_status = 'F' then 
           update r5wsmessagestatus set WSS_RETRYSUSPEND = '+'
             where  wss_code = rec_ion.ion_wsscode
             and    nvl(WSS_RETRYSUSPEND,'-') = '-';
        end if;*/
              end if;
      end if; 
    
      --For IVMS inbound
      if vComponentID ='IVMS' and vTaskID is not null then
               vSource:=vComponentID;
               vDest:='EAM';
               if instr(vTaskID,':') > 0 then
          for rec_task in cur_task(vTaskID) loop
                     if rec_task.level = 1 then 
            vTrans := rec_task.corr_text;
                     elsif rec_task.level = 2 then 
            vKeyFld1  := rec_task.corr_text;   
                     elsif rec_task.level = 3 then 
              vLenPre := length(vTrans)+length(vKeyFld1)+3; 
            vKeyFld2 := substr(vTaskID,vLenPre+1,length(vTaskID)-vLenPre); 
                     end if;
                  end loop;
          if wss.wss_document = 'SyncAssetMeterReading' then
            begin
             vHeaderPath := '/soapenv:Envelope/soapenv:Body/ns1:'||wss.wss_document||'/ns1:DataArea/ns1:AssetMeterReading/ns1:AssetMeterReadingHeader/';
             vLinePath := '/soapenv:Envelope/soapenv:Body/ns1:'||wss.wss_document||'/ns1:DataArea/ns1:AssetMeterReading/ns1:AssetMeterReadingLine/';
             select XMLQUERY (vXMLQuery_ns ||vHeaderPath ||
             'ns1:Asset/ns1:ID/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vAssetID from dual;    
             
             select XMLQUERY (vXMLQuery_ns ||vLinePath ||
             'ns1:MeterReference/ns1:UOMCode/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vKeyFld3 from dual;  
             
             select XMLQUERY (vXMLQuery_ns ||vLinePath ||
             'ns1:ReadingQuantity/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vKeyFld4 from dual;
           
            exception when others then 
            null;
            end;
          end if;
          if wss.wss_document = 'SyncAssetTrackingData' then
             begin
             vHeaderPath := '/soapenv:Envelope/soapenv:Body/ns1:'||wss.wss_document||'/ns1:DataArea/ns1:AssetTrackingData/';
             select XMLQUERY (vXMLQuery_ns ||vHeaderPath ||
             'ns1:PromptData[2]/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vAssetID from dual;    
             
             select XMLQUERY (vXMLQuery_ns ||vHeaderPath ||
             'ns1:PromptData[3]/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vKeyFld3 from dual;  
             
             select XMLQUERY (vXMLQuery_ns ||vHeaderPath ||
             'ns1:PromptData[4]/text()' 
             PASSING XMLTYPE(vMsgText) RETURNING CONTENT).getStringVal() 
             into vKeyFld4 from dual;
           
            exception when others then 
            null;
            end;
          end if;
         
          update u5ionmonitor i
          set i.ion_source = vSource,i.ion_destination = vDest,i.ion_trans = SUBSTR(vTrans,1,10), i.ion_ref = vRefDoc,                   
            i.ion_keyfld1 = vKeyFld1 ||'#'||vAssetID, i.ion_keyfld2 = vKeyFld2,i.ion_keyfld3 = vKeyFld3,i.ion_keyfld4 = vKeyFld4,
            i.ion_status = r5o7.o7get_desc('EN','UCOD', wss.wss_req_status,'MQST', ''),
            i.ion_message = replace(wss.wss_req_message,chr(10),'') 
          where i.ion_transid = rec_ion.ion_transid; 
               end if; --instr(vTaskID,':') > 0
            
      end if; --vComponentID ='IVMS'
      
    end if;
     exception when no_data_found then
       null;
     when others then 
       null;
     end; 
 end loop;
 
update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
end if; --ucd.ucd_id = 6 and ucd.ucd_recalccost = '+'
 
end;