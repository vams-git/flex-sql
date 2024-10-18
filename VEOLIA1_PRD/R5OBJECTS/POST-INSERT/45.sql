declare 
  obj             r5objects%rowtype;
  mae             r5mailevents%rowtype;
  vFlag           varchar2(1) := 'N';
  vMailTemp       r5mailevents.mae_template%type;
  vAuditList      r5mailevents.mae_param1%type;
  vCnt            number;
  
  cursor cur_ava (vObj varchar2,vOrg varchar2) is
  select aat_column,ava_from,ava_to,ava_changed
  from   r5audvalues,r5audattribs
  where  ava_table = aat_table and ava_attribute = aat_code
  and    ava_primaryid = vObj and ava_secondaryid = vOrg
  and    ava_updated = '+'
  and    ava_table = 'R5OBJECTS'
  and    aat_table ='R5OBJECTS' and aat_column in ('OBJ_OPERATIONALSTATUS','OBJ_UDFCHAR36','OBJ_UDFCHAR37','OBJ_UDFCHAR38')
  and    abs(sysdate - ava_changed) * 24 * 60 * 60 <= 2;
begin
  select * into obj from r5objects where rowid =:rowid;
  if obj.obj_org in ('TAS','VIC','WAR','WAU','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP') and obj.obj_obrtype ='A' and obj.obj_udfchar40 is not null then
	  vFlag := 'Y';
	  if obj.obj_org = 'TAS' then
		 mae.mae_param1 := 'gael.daley@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'VIC' then
             mae.mae_param1 := 'marie.lim@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NSW' then
             mae.mae_param1 := 'skye.bullock@veolia.com; rani.chand@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'QLD' then
             mae.mae_param1 := 'yann.josse@veolia.com; rani.chand@veolia.com; justine.brooking@veolia.com; amanda.knight@veolia.com; leon.webster@veolia.com; fleet.datateam@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NTE' then
             mae.mae_param1 := 'yann.josse@veolia.com; fleet.datateam@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NVE' then
             mae.mae_param1 := 'yann.josse@veolia.com; fleet.datateam@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NVW' then
             mae.mae_param1 := 'yann.josse@veolia.com; fleet.datateam@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NVP' then
             mae.mae_param1 := 'yann.josse@veolia.com; fleet.datateam@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'SAU' then
             mae.mae_param1 := 'damian.jachmann@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'WRR' then
             mae.mae_param1 := 'samantha.doyle@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'NWA' then
             mae.mae_param1 := 'samantha.doyle@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
          elsif obj.obj_org = 'WAU' then
             mae.mae_param1 := 'samantha.doyle@veolia.com; fleet.datateam@veolia.com; yann.josse@veolia.com; afiq.rostam@veolia.com';
	  end if;
	  mae.mae_param2 := obj.obj_code;
	  mae.mae_param3 := obj.obj_org;
	  mae.mae_param4 := to_date(o7gttime(obj.obj_org),'DD-MON-YYYY');
	  mae.mae_param5 := obj.obj_desc;
	  mae.mae_param6 := obj.obj_udfchar40;
	   
	  
	  if obj.OBJ_OPERATIONALSTATUS is not null then
		 mae.mae_param7 := 'VAMS Operational Status: ' || r5o7.o7get_desc('EN','UCOD',obj.OBJ_OPERATIONALSTATUS,'EOST', null);
	  end if;
	  
	  if obj.OBJ_UDFCHAR36 is not null then
		 mae.mae_param8 := 'SAP Asset Class: ' || obj.OBJ_UDFCHAR36;
	  end if;
	  
	  if obj.OBJ_UDFCHAR38 is not null then
		 mae.mae_param9 := 'SAP Asset Plant: ' || obj.OBJ_UDFCHAR38;
	  end if;
	  
	  if obj.OBJ_UDFCHAR37 is not null then
		 mae.mae_param10 := 'SAP Asset Cost Centre: ' || r5o7.o7get_desc('EN','CSTC',obj.OBJ_UDFCHAR37,'', '');
	  end if;
	  /*if rec_ava.aat_column = 'OBJ_UDFNUM06' then
		 mae.mae_param11 := 'Net Book Value / WDV: From ' || rec_ava.ava_from || 
						   ' to '|| rec_ava.ava_to;
	  end if;*/
	  select 
	  decode(mae.mae_param7,null,null,mae.mae_param7 || chr(10))|| 
	  decode(mae.mae_param8,null,null,mae.mae_param8 || chr(10))|| 
	  decode(mae.mae_param9,null,null,mae.mae_param9 || chr(10))|| 
	  decode(mae.mae_param10,null,null,mae.mae_param10 || chr(10))/*|| 
	  decode(mae.mae_param11,null,null,mae.mae_param11 || chr(10))*/
	  into vAuditList
	  from dual;
          
      if vFlag  ='Y' then
         vMailTemp := 'M-FLEET-OBJ-CREATE';
         select count(1) into vCnt from r5mailevents where 
         mae_template = vMailTemp
         and mae_param2 = mae.mae_param2
         and mae_param3 =  mae.mae_param3
         and abs(sysdate - mae_date) * 24 * 60 * 60 <= 2;
         
         if vCnt = 0 then
         insert into r5mailevents
         (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,MAE_ATTRIBPK,
         MAE_PARAM1,
         MAE_PARAM2,
         MAE_PARAM3,
         MAE_PARAM4,
         MAE_PARAM5,
         MAE_PARAM6,
         MAE_PARAM7/*,
         MAE_PARAM8,
         MAE_PARAM9,
         MAE_PARAM10,
         MAE_PARAM11*/
         ) 
        values
        (S5MAILEVENT.NEXTVAL,vMailTemp,sysdate,'-','N',0,
         mae.mae_param1,
         mae.mae_param2,
         mae.mae_param3,
         mae.mae_param4,
         mae.mae_param5,
         mae.mae_param6,
         vAuditList
         /*
         mae.mae_param7,
         mae.mae_param8,
         mae.mae_param9,
         mae.mae_param10,
         mae.mae_param11*/);
         end if;
      end if;
  end if;
  
exception 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5OBJECTS/45/I - '||SQLCODE || SQLERRM) ;   
end;