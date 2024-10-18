declare 
  wss             r5wsmessagestatus%rowtype;
  vCnt            number;
  vSource           varchar2(80);
  vKeyFld1         varchar2(80);
  vXMLSeqNo        varchar2(80);
  vPreVariationID  varchar2(80);
  vVariationID     varchar2(80);
  vReq_Msgind      r5wsmessages.wsm_msgind%type;
  vMsgText         r5wsmessages.wsm_text%type;
  vNoun            varchar2(30);
  vXMLQuery_ns     varchar2(800);
  vResult          varchar2(30);
  vResultDetails   varchar2(4000);
  vResultRequistID varchar2(80);
  vIONStatus       varchar2(4);
  
  
  cursor cur_TransportAttributes(InData clob) is
  select t.*
  from
  XMLTable(
  xmlnamespaces (
  'http://schemas.xmlsoap.org/soap/envelope/' as "soapenv",
  'http://eam.infor.com/databridge/processing' as "pr"
   --default 'http://tempuri.org/'
  ),
 '/soapenv:Envelope/soapenv:Header/pr:TransportAttributes/pr:Parameter'
  PASSING XMLTYPE.createXML(InData)
   COLUMNS
     NameDesc   varchar2(80)       PATH '@name',                       
     NameValue  varchar2(80)       PATH '@value'
   ) t;
   
begin
  select * into wss from r5wsmessagestatus where rowid=:rowid; 
  --Update Inbound ServiceRequest Result
  /*if wss.wss_document = 'ProcessCustomerCall' then 
     select count(1) into vCnt from u5ionmonitor where ion_ref = wss.wss_code;
     if vCnt > 0 then
       select ion_source,ion_keyfld1 into vSource,vKeyFld1 from u5ionmonitor where ion_ref = wss.wss_code;
       update r5wsmessagestatus w
       set w.wss_org = vSource, w.wss_desc = vKeyFld1
       where rowid=:rowid and w.wss_desc is null;
       
       if wss.wss_req_status = 'F' then
          update u5ionmonitor 
          set ion_status ='E',ion_message = wss.wss_req_message,
              ion_update = wss.wss_rsp_time
          where ion_ref = wss.wss_code;
       end if;
       
       if  wss.wss_req_status = 'C' then
           update u5ionmonitor
           set    ion_status ='S',ion_message = wss.wss_req_message,
                  ion_update = wss.wss_rsp_time
           where ion_ref = wss.wss_code;
           --delete from u5ionmonitor where ion_ref = wss.wss_req_msgind;
       end if;
     end if;
  end if;
  */
  
  --Insert Work order outbound data to ion monitor
  begin
    if wss.wss_partner IN ('INFOR-ONRAMP','INFOR-IMS') and wss.wss_document = 'SyncMaintenanceOrder' then
       vXMLSeqNo := substr(wss.wss_contextid,instr(wss.wss_contextid,':')+1);
       vPreVariationID := substr(wss.wss_correlationid,instr(wss.wss_correlationid,vXMLSeqNo));
       begin
          select corr_text into vVariationID from (
          select regexp_substr(vPreVariationID,'[^.]+', 1, level) as corr_text,level from dual
          connect by regexp_substr(vPreVariationID, '[^.]+', 1, level) is not null
          order by level desc
          ) where rownum<= 1;
       exception when no_data_found then
          vVariationID := null;
       end;

       if wss.wss_rsp_msgind is not null then
          select count(1) into vCnt from u5ionmonitor ion where ion.ion_xmlseqno = vXMLSeqNo;
          if vCnt > 0 then
             update u5ionmonitor ion 
             set ion.ion_ref = wss.Wss_Code,
             ion.ion_variationid = vVariationID,
             ion.ion_req_wsmmsg = wss.wss_rsp_msgind,
             ion.ion_data = (select wsm.wsm_text from r5wsmessages wsm where wsm.wsm_msgind = wss.wss_rsp_msgind),
             ion.ion_status = decode(wss.wss_rsp_status,'C','P','E')
             where ion.ion_xmlseqno = vXMLSeqNo;
             
             --UPDATE skip status because data is out of date
             if wss.wss_req_status ='F' and wss.wss_req_message like '%The data of this record is out of date%' then
                update u5ionmonitor ion 
                set ion.ion_status ='SKIP'
                where ion.ion_xmlseqno = vXMLSeqNo;
                --delete from u5ionmonitor where ion.ion_xmlseqno = vXMLSeqNo;
             end if;
          end if;
       end if;
    end if;
  exception when others then 
    null;
  end;
  
  --Update Work order outbound data result
  begin
     if wss.wss_partner IN ('INFOR-ONRAMP','INFOR-IMS') and wss.wss_document IN ('SyncQLDC_UpdateRequest') then 
        select wsm.wsm_text into vMsgText from r5wsmessages wsm where wsm.wsm_msgind = wss.wss_req_msgind;
        --get variation id
        vNoun := 'UpdateRequest';
            
        vPreVariationID := substr(wss.wss_correlationid,1,instr(wss.wss_correlationid,':')-1);
        begin
            select corr_text into vVariationID from (
            select regexp_substr(vPreVariationID,'[^.]+', 1, level) as corr_text,level from dual
            connect by regexp_substr(vPreVariationID, '[^.]+', 1, level) is not null
            order by level desc
            ) where rownum<= 1;
        exception when no_data_found then
            vVariationID := null;
        end;
        
        if vVariationID is not null then
          /*update r5wsmessagestatus wss
          set --wss_retrysuspend = '+',
          wss_req_status ='C',wss_req_rstatus ='C',
          wss_req_message = vVariationID
          where rowid=:rowid; --and nvl(wss_retrysuspend,'-') = '-';*/
          --Check ION Status
          begin
             select ion_status into vIONStatus from u5ionmonitor where ion_variationid = vVariationID
             and rownum<=1;
          exception when no_data_found then
             vIONStatus := 'NF';              
          end;
          
          if vIONStatus in ('P','NF') then
            --Get Result
            vXMLQuery_ns := 'declare namespace soapenv = "http://schemas.xmlsoap.org/soap/envelope/"; (: :)  
                            declare namespace ns2  = "urn:queenstownlakesdistrictcouncil:services:regulatory:rfs:veolia"; (: :)
                            declare namespace soap = "http://schemas.xmlsoap.org/soap/envelope/"; (: :)
                            ';

            select XMLQUERY (  
             vXMLQuery_ns || 
             '/soapenv:Envelope/soapenv:Body/'||wss.wss_document||'/DataArea/QLDC_'||vNoun||
             '/soap:Envelope/soap:Body'||
             '/ns2:'||vNoun||'Response/ns2:'||vNoun||'Result/@Result' 
            PASSING XMLTYPE(vMsgText) 
            RETURNING CONTENT ).getStringVal() into vResult
            from dual;
            select XMLQUERY (  
             vXMLQuery_ns || 
             '/soapenv:Envelope/soapenv:Body/'||wss.wss_document||'/DataArea/QLDC_'||vNoun||
             '/soap:Envelope/soap:Body'||
             '/ns2:'||vNoun||'Response/ns2:'||vNoun||'Result/@ResultDetails' 
            PASSING XMLTYPE(vMsgText) 
            RETURNING CONTENT ).getStringVal() into vResultDetails
            from dual;
            select XMLQUERY (  
             vXMLQuery_ns || 
             '/soapenv:Envelope/soapenv:Body/'||wss.wss_document||'/DataArea/QLDC_'||vNoun||
             '/soap:Envelope/soap:Body'||
             '/ns2:'||vNoun||'Response/ns2:'||vNoun||'Result/@RequestId' 
            PASSING XMLTYPE(vMsgText) 
            RETURNING CONTENT ).getStringVal() into vResultRequistID
            from dual;
            
            update r5wsmessagestatus wss
            set --wss_retrysuspend = '+',
            wss_req_status ='C',wss_req_rstatus ='C',
            wss_req_message = substr(vResultRequistID||'-'||vResult||'-'||vResultDetails,1,1000)
            where rowid=:rowid; --and nvl(wss_retrysuspend,'-') = '-';
            
            update u5ionmonitor ion
            set ion_status = decode(vResult,'ERROR','Failed','Completed'),
                ion_message = substr(vResultRequistID||'-'||vResult||'-'||vResultDetails,1,4000),
                --ion.ion_sendemail = decode(vResult,'ERROR','+','-'),
                ion_update = wss.wss_req_time,
                --ion.ion_req_wsmmsg = wss.wss_req_msgind,
                ion.ion_rsp_wsmmsg = wss.wss_rsp_msgind,
                ion.ion_wsscode = wss.wss_code,
                ion.ion_messageid = wss.wss_contextid
                --ION_RSP_WSMMSG =wss.wss_code
            where ion.ion_variationid = vVariationID
            and   ion.ion_status in ('P');
            /*if vResult = 'SUCCESS' then
              delete from u5ionmonitor where ion_variationid = vVariationID;
            end if;*/
          end if;
        end if;
     end if;     
  exception when others then 
    null;
  end;
  
 -- null;
end;