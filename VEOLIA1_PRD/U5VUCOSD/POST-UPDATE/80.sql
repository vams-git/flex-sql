declare 
     ucd              u5vucosd%rowtype;
	 
	 cursor cur_ion is
	 select * from u5ionmonitor 
	 where ion_source ='EAM' and ion_destination = 'SAP'
	 and ion_xmlseqno is not null
	 and (
	  ion_status in ('New') 
	  or   
	  (ion_status in ('Failed') and exists (select 1 from r5wsreqhist where 
	  wsq_message = ion_wsscode and (sysdate - wsq_time) * 24 * 60 < 10))
	  ); 
	 vContectID     r5wsmessagestatus.wss_contextid%type;
	 vDocument      r5wsmessagestatus.wss_document%type;
	 vDocument_DE   r5wsmessagestatus.wss_document%type;
	 vStatus        u5ionmonitor.ion_status%type;
	 vCurrDate      date;
	 wss            r5wsmessagestatus%rowtype;
begin
 select * into ucd from u5vucosd where rowid=:rowid;
 if ucd.ucd_id = 8 and ucd.ucd_recalccost = '+' then
     for rec_ion in cur_ion loop
		 begin
			if rec_ion.ion_trans in ('REQ','PORL','TRAN','BOOK') then 
			  if rec_ion.ion_trans in ('REQ') then
				 vContectID :=  'REQUISITIONS('||rec_ion.ion_keyfld1||','||rec_ion.ion_keyfld2||'):'||rec_ion.ion_xmlseqno;
				 vDocument  :=  'SyncRequisition';
				 vDocument_DE := 'ADDREQUISTN'; 
			  end if;
			  if rec_ion.ion_trans in ('PORL') then
				 vContectID :=  'ORDERS('||rec_ion.ion_keyfld1||','||rec_ion.ion_keyfld4||'):'||rec_ion.ion_xmlseqno;
				 vDocument  :=  'SyncPurchaseOrder';
				 vDocument_DE := 'CHANGEPO'; 
			  end if;
			  if rec_ion.ion_trans in ('TRAN') then
				 vContectID :=  'TRANSACTIONS('||rec_ion.ion_keyfld1||'):'||rec_ion.ion_xmlseqno;
				 vDocument  :=  'SyncReceiveDelivery';
				 vDocument_DE := 'PORECEIVEPARTS';
			  end if;
			  if rec_ion.ion_trans in ('BOOK') then
				 vContectID :=  'BOOKEDHOURS('||'%'||rec_ion.ion_keyfld5||'%):'||rec_ion.ion_xmlseqno;
				 vDocument  :=  'SyncServiceConsumption';
				 vDocument_DE := 'PORECEIVESERVICE'; 
			  end if;      
			   
			   begin			 
				 select * into wss from 
				 (select * from r5wsmessagestatus w
				 where w.wss_contextid like vContectID and w.wss_document = vDocument
				 and   w.wss_type = 'BD'
				 order by w.wss_code desc
				 ) where rownum <= 1;
				  
				 update u5ionmonitor i
				 set    ion_status = r5o7.o7get_desc('EN','UCOD', wss.wss_req_status,'MQST', ''),
						ion_message = replace(wss.wss_req_message,chr(10),''),
						i.ion_req_wsmmsg = wss.wss_req_msgind,
						i.ion_rsp_wsmmsg = wss.wss_rsp_msgind,
						i.ion_wsscode = wss.wss_code,
						i.ion_messageid = wss.wss_correlationid,
						i.ion_update = sysdate --case when rec_ion.ion_org is null then sysdate else o7gttime(rec_ion.ion_org) end
				 where  ion_transid = rec_ion.ion_transid;
				 
				 if rec_ion.ion_trans in ('REQ') and wss.wss_rsp_status = 'C' then 
					update r5requisitions
					set req_status ='02WA'
					where req_code = rec_ion.ion_keyfld1
					and   req_org = rec_ion.ion_keyfld2
					and   req_status = '01SS';
				 end if; 
				 
				 if rec_ion.ion_trans in ('PORL') and wss.wss_rsp_status = 'C' then 
					update r5orderlines
					set orl_udfchkbox02 = '-'
					where orl_order = rec_ion.ion_keyfld1 
					and   orl_ordline = rec_ion.ion_keyfld2
					and   orl_order_org = rec_ion.ion_keyfld4
					and   nvl(orl_udfchkbox02,'-') = '+';
				 end if;

			  exception when no_data_found then
				begin
				 --check de TRANSACTION if DE is fail update ION Interface montior to fail
					 select * into wss from 
					 (select * from r5wsmessagestatus w
					 where w.wss_contextid like vContectID and w.wss_document = vDocument_DE
					 and   w.wss_type = 'DE'
					 order by w.wss_code desc
					 ) where rownum <= 1;
					 if wss.wss_req_status = 'F' then 
						update u5ionmonitor i
						set ion_status = r5o7.o7get_desc('EN','UCOD', wss.wss_req_status,'MQST', ''),
							ion_message = replace(wss.wss_req_message,chr(10),''),
							i.ion_req_wsmmsg = wss.wss_req_msgind,
							i.ion_rsp_wsmmsg = wss.wss_rsp_msgind,
							i.ion_wsscode = wss.wss_code,
							i.ion_messageid = wss.wss_correlationid,
							i.ion_update = sysdate--case when rec_ion.ion_org is null then sysdate else o7gttime(rec_ion.ion_org) end
						where  ion_transid = rec_ion.ion_transid;
					 end if;
				exception when no_data_found then
					null;
				end;
			  end;
			  
			  
			  
			end if; 
		 exception when others then 
			null;
		 end; 
	 end loop;
 
update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
end if; --ucd.ucd_id = 9 and ucd.ucd_recalccost = '+'
 
end;