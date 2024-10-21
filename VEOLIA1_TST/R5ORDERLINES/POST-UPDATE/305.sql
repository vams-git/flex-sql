declare 
 orl              r5orderlines%rowtype;
 vNewValue        r5audvalues.ava_to%type;
 vOldValue        r5audvalues.ava_from%type;
 vTimeDiff        number;
 
  vAddComm		  varchar2(80);
  vComment        varchar2(4000);
  vLine           number;
  vOrdDesc        r5orders.ord_desc%type;
  
  iErrMsg          varchar2(400);
  err_val          exception;
 
  
cursor cur_evt(vOrg varchar2,vOrd varchar2) is 
select distinct orl_event 
from r5orderlines 
where orl_order_org = vOrg and orl_order = vOrd
and   orl_event is not null;


begin
  select * into orl from r5orderlines where rowid=:rowid;
  
  --if orl.orl_sourcesystem = 'SAP' and nvl(orl.orl_udfchkbox01,'-') = '-'  then
  if orl.orl_sourcesystem = 'SAP'  then
    -- Insert into XMLTRANS to export to ION
    begin
      select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
      from (
      select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
      from r5audvalues,r5audattribs
      where ava_table = aat_table and ava_attribute = aat_code
      and   aat_table = 'R5ORDERLINES' and aat_column = 'ORL_STATUS'
      and   ava_table = 'R5ORDERLINES' 
      and   ava_primaryid = orl.orl_order
      and   ava_secondaryid = orl.orl_order_org ||' '||orl.orl_ordline
      and   ava_updated = '+'
      and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
      order by ava_changed desc
      ) where rownum <= 1;
    exception when no_data_found then 
      vNewValue := null;
      return;
    end;
	
	if nvl(orl.orl_udfchkbox01,'-') = '-' then
		if vNewValue in ('A','CP','CAN') and vOldValue not in ('U') then
			update r5orderlines
			set orl_udfchkbox02 = '+'
			where rowid=:rowid
			and  nvl(orl_udfchkbox02,'-') <> '+';
			  
			update r5orders
			set    ord_udfchkbox01 = '+'
			where  ord_org = orl.orl_order_org and ord_code = orl.orl_order
			and    nvl(ord_udfchkbox01,'-') <> '+';
		end if; --vNewValue in ('A','CP','CAN') 
	end if;

	if vNewValue in ('CP') and vOldValue not in ('U') then
	     begin
			select opa_desc into vAddComm from r5organizationoptions where opa_code = 'PURLOGW' and opa_org = orl.orl_order_org;
		 exception when no_data_found THEN
			vAddComm := 'NO';
		 end;
		 if vAddComm = 'YES' then
		   select ord_desc into vOrdDesc from r5orders where ord_org = orl.orl_order_org  and ord_code = orl.orl_order;
		   vComment :=  'Completely Received PO-Line#' || orl.orl_order || '-' || orl.orl_ordline || ' ' || vOrdDesc ;
		   for rec_evt in cur_evt(orl.orl_order_org,orl.orl_order) loop
		   	   begin
				  select add_line into vLine from
                  (select add_line,R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)as add_text
                  from r5addetails
                  where add_entity='EVNT' and add_code=rec_evt.orl_event and add_lang = 'EN')
                  where add_text like vComment;
				
		       exception when no_data_found then
				   select nvl(max(add_line),0) + 10 into vLine
				   from r5addetails where add_entity = 'EVNT' and add_code = rec_evt.orl_event;
				   insert into r5addetails
				   (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
				   values
				   ('EVNT','EVNT','*','*',rec_evt.orl_event,'EN',vLine,'+',vComment,o7gttime(orl.orl_order_org));
			   end;
		   end loop;
		 end if;
	end if;
   
   end if; --orl.orl_sourcesystem = 'SAP'
  
exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5orderlines/Update/305') ;
end;
 