declare 
ucd              u5vucosd%rowtype;
vXMLSeqNum       r5xmltranstatus.xts_seqnum%type;
vTransID         R5GLINTERFACE.GLI_TRANSID%TYPE;
vRunID           R5GLINTERFACE.GLI_RUNID%type;
vEntryID         R5GLINTERFACE.GLI_ENTRYID%type;
vOrgCurr         R5ORGANIZATION.ORG_CURR%type;
vBookid          R5ORGANIZATION.Org_Bookid%type;

vGli_Process          r5glinterface.gli_process%type;
vGli_Deb_Segment4     r5glinterface.gli_segment4%type;
vGli_Deb_Segment2     r5glinterface.gli_segment2%type;
vGli_Deb_Segment3     r5glinterface.gli_segment3%type;
vGli_Deb_glnomacct    r5glinterface.gli_glnomacct%type;
vGli_Cre_Segment4     r5glinterface.gli_segment4%type;
vGli_Cre_Segment2     r5glinterface.gli_segment2%type;
vGli_Cre_Segment3     r5glinterface.gli_segment3%type;
vGli_Cre_glnomacct    r5glinterface.gli_glnomacct%type;
vRef1                 r5glinterface.gli_reference1%type;

vYear                 varchar2(10);
vMonth                varchar2(10);
vWeek                 varchar2(10);
vAlloc                varchar2(20);
vSAPPostingdate       date;
vGl_createdate        date;
vGLLinenumber       number;
vCreAvgPrice        r5fuelissues.fli_price%type;
vCreTotalQty        r5fuelissues.fli_qty%type;
vDebCost        r5fuelissues.fli_price%type;
vCreTotalCost         r5fuelissues.fli_price%type;

vGrpCode              r5fuelissues.fli_udfchar01%type;

chk              VARCHAR2(3);
--Generate Debit Records, DO NOT group
cursor cur_deb(vCompc varchar2,vOrg varchar2,vDepClass varchar2,vDepCode varchar2,vTType varchar2,
               vDocDate date,vSeg2 varchar2,vSeg3 varchar2,vSeg4 varchar2) is   
select 
fli_udfchar03 as compc,dep_org,dep_class,dep_code,dep_desc,dep_udfchar03,
fli_udfchar01 as obj_wbs,fli_udfchar02 as dep_prof,fli_udfchar05 as dep_gl,fli_udfchar06 as fue_gl,
fli_udfchar04 as obj_desc,
fli_udfdate01,
case when fli_qty>0 then 'I' else 'R' end as ttype,
fli_qty,fli_price,fli_code
from r5fuelissues fli,r5depots dep
where fli_depot = dep_code and fli_depot_org = dep_org
and   nvl(fli.fli_udfchkbox01,'-') = '-'
and   fli.fli_udfdate01 is not null
and   dep.dep_class <> 'GIF' 
--and dep.dep_class = 'CRD'
and  fli_udfchar03 = vCompc and dep_org = vOrg and dep_class = vDepClass and dep_code = vDepCode
and  case when fli_qty>0 then 'I' else 'R' end = vTType
and  fli_udfdate01 = vDocDate
and  case when fli_qty>0 then ' ' else fli_udfchar01 end = nvl(vSeg2,' ')
and  case when fli_qty>0 then fli_udfchar02 else ' ' end =    nvl(vSeg3,' ')
and  case when fli_qty>0 then fli_udfchar05 else fli_udfchar06 end =    nvl(vSeg4,' ');

--Generate Credit Records, GROUP records
cursor cur_cre is 
select compc,dep_org,dep_class,dep_code,dep_desc,ttype,fli_udfdate01,
decode(ttype,'I',null,obj_wbs) as cre_seg2,
decode(ttype,'I',dep_prof,null) as cre_seg3,
decode(ttype,'I',dep_gl,fue_gl) as cre_seg4,
sum(fli_qty * fli_price) as fcost,sum(fli_qty) as fqty,min(fli_code) as fli_code
from 
(
select 
fli_udfchar03 as compc,dep_org,dep_class,dep_code,dep_desc,
fli_udfchar01 as obj_wbs,fli_udfchar02 as dep_prof,fli_udfchar05 as dep_gl,fli_udfchar06 as fue_gl,
case when fli_qty>0 then 'I' else 'R' end as ttype,
fli_udfdate01,fli_qty,fli_price,fli_code
from r5fuelissues fli,r5depots dep
where fli_depot = dep_code and fli_depot_org = dep_org
and   nvl(fli.fli_udfchkbox01,'-') = '-'
and   fli.fli_udfdate01 is not null
and   dep.dep_class <> 'GIF' 
--and dep.dep_class = 'CRD'
)
group by compc,dep_org,dep_class,dep_code,dep_desc,ttype,fli_udfdate01,
decode(ttype,'I',null,obj_wbs),
decode(ttype,'I',dep_prof,null), 
decode(ttype,'I',dep_gl,fue_gl) 
order by compc,dep_org,dep_class,dep_code;
  
begin  
select * into ucd from u5vucosd where rowid=:rowid;
if ucd.ucd_id = 7 and ucd.ucd_recalccost = '+' then
   for r_cre in cur_cre loop  -- group credit
	   vGLLinenumber := 0;
	   vCreTotalQty := 0;
	   vCreTotalCost := 0;
	   vGrpCode := r_cre.fli_code;
	   vXMLSeqNum := s5xmltranstatus.nextval;
	   r5o7.o7maxseq(vRunID,'GLR', '1', chk );
	   r5o7.o7maxseq(vEntryID, 'GLE', '1', chk );
	   select org_curr,decode(org_curr,'NZD','2','1')
	   into vOrgCurr,vBookid
	   from r5organization
	   where org_code = r_cre.Dep_Org;
	   for r_deb in cur_deb(r_cre.compc,r_cre.dep_org,r_cre.dep_class,r_cre.dep_code,r_cre.ttype,
						  r_cre.fli_udfdate01,r_cre.cre_seg2,r_cre.cre_seg3,r_cre.cre_seg4) loop
		  vGLLinenumber := vGLLinenumber + 1;
  
		  vCreTotalQty := vCreTotalQty + r_deb.fli_qty;
  
		  vDebCost := round(abs(r_deb.fli_qty * r_deb.fli_price),2);
		  vCreTotalCost := vCreTotalCost + vDebCost;
		  vSAPPostingdate := r_deb.fli_udfdate01;
		  vMonth := to_char(vSAPPostingdate,'Mon');
		  select 
		  case when vSAPPostingdate between to_date('20221226','YYYYMMDD')and to_date('20230101','YYYYMMDD') then '53' 
		  when vSAPPostingdate <= to_date('20221226','YYYYMMDD') then to_char(vSAPPostingdate+ 7,'iw') else to_char(vSAPPostingdate,'iw') end
		  into vWeek from dual;
		  select  
		  case when vSAPPostingdate between to_date('20221226','YYYYMMDD')and to_date('20230101','YYYYMMDD') then '22' 
		  when vSAPPostingdate <= to_date('20221226','YYYYMMDD') then to_char(vSAPPostingdate+7,'YY') else to_char(vSAPPostingdate,'YY') end
		  into vYear from dual;
		  vAlloc := substr(vMonth ||'-'|| vYear ||' Wk'|| vWeek  ||'-'||  r_deb.Dep_Desc,1,18);   
      
      
		  if r_deb.fli_qty > 0 then
			 vGli_Process := 'GL-ISSUEFUEL';
			 vGl_createdate := sysdate;
			 vRef1 := substr('IF '||r_deb.fli_code || ' ' ||r_deb.obj_desc,1,40);
			 if r_deb.dep_class = 'CRD' then
				vGli_Process := 'GL-ISSUEFUELCRD';
				vGl_createdate := r_deb.fli_udfdate01;
				select substr(decode(r_deb.dep_udfchar03,null,
				'IF '||r_deb.fli_code || ' ' ||r_deb.obj_desc,
				'IF '||r_deb.dep_udfchar03 || ' ' || r_deb.fli_code || ' ' ||r_deb.obj_desc)
				,1,40) into vRef1
				from dual;
			 end if;
			 vGli_Deb_Segment4 := r_deb.fue_gl;--'51311200';
			 vGli_Deb_Segment2 := r_deb.obj_wbs;
			 vGli_Deb_Segment3 := null;
			 vGli_Deb_glnomacct := r_deb.obj_wbs||r_deb.fue_gl;--'51311200';
		  else
			 vGli_Process := 'GL-ISSUEFUEL-C';
			 vGl_createdate := sysdate;
			 if r_deb.dep_class = 'CRD' then
				vGli_Process := 'GL-ISSUEFUELCRD-C';
				vGl_createdate := r_deb.fli_udfdate01;
			 end if;
			 vGli_Deb_Segment4 := r_deb.dep_gl;--'16219010';
			 vGli_Deb_Segment2 := null;
			 vGli_Deb_Segment3 := r_deb.dep_prof;
			 vGli_Deb_glnomacct := 'DEPOT PROFIT CENTER'||r_deb.dep_gl;
			 vRef1 := substr(vMonth||'-'||vYear||' Week ' ||vWeek ||' - '||r_cre.dep_desc, 1,40);
		  end if;  
          
		  --insert debit NOT Group
		 r5o7.o7maxseq(vTransID,'GLI', '1', chk );
		 insert into r5glinterface
		(GLI_TRANSID,GLI_RUNID,GLI_ENTRYID,GLI_SEQNUM,
		 GLI_PROCESS,GLI_GROUP,GLI_STATUS,GLI_CREATEDBY,GLI_ACTUALFLAG,GLI_USERJECATEGORYNAME,GLI_USERJESOURCENAME,
		 GLI_ACCOUNTINGDATE,GLI_TRANSACTIONDATE,GLI_DATECREATED,
		 GLI_SETOFBOOKSID,GLI_CURRENCYCODE,
		 GLI_SEGMENT1,GLI_SEGMENT2,GLI_SEGMENT3,GLI_SEGMENT4,
		 GLI_ENTEREDDR,GLI_ENTEREDCR,
		 GLI_REFERENCE1,GLI_ATTRIBUTE1,GLI_ATTRIBUTE2,GLI_ATTRIBUTE3,GLI_ATTRIBUTE4,GLI_ATTRIBUTE5,GLI_ATTRIBUTE6,GLI_GLNOMACCT,
		 GLI_ORG)
		 VALUES
		 (vTransID,vRunID,vEntryID,vXMLSeqNum,
		 vGli_Process,1,'NEW',1,'A','RFBU','GAMA',
		 vSAPPostingdate,vSAPPostingdate,sysdate,
		 vBookid,vOrgCurr,
		 NULL,vGli_Deb_Segment2,vGli_Deb_Segment3,vGli_Deb_Segment4,
		 round(abs(r_deb.fli_qty * r_deb.fli_price),2),NULL,
		 vRef1,null,vGrpCode,vAlloc,r_deb.fli_qty,vGLLinenumber,r_deb.fli_code,vGli_Deb_glnomacct,
		 r_deb.dep_org
		 );
			
		update r5fuelissues
		set fli_udfchkbox01 ='+',
			fli_udfdate02 = o7gttime(r_deb.dep_org),
			fli_udfchar07 = vGrpCode
		where fli_code = r_deb.fli_code;
                
      end loop;
         
	--insert group Credit
	vGLLinenumber := vGLLinenumber + 1;
	vGli_Cre_Segment4 := r_cre.cre_seg4;--dep_gl;--'16219010';
	vGli_Cre_Segment2 := r_cre.cre_seg2;--wbs;
	vGli_Cre_Segment3 := r_cre.cre_seg3;--rec.dep_prof;
	vGli_Cre_glnomacct := 'DEPOT PROFIT CENTER'||r_cre.cre_seg4;
	
	vSAPPostingdate := r_cre.fli_udfdate01;
	vMonth := to_char(vSAPPostingdate,'Mon');
	select 
	case when vSAPPostingdate between to_date('20221226','YYYYMMDD')and to_date('20230101','YYYYMMDD') then '53' 
	when vSAPPostingdate <= to_date('20221226','YYYYMMDD') then to_char(vSAPPostingdate+ 7,'iw') else to_char(vSAPPostingdate,'iw') end
	into vWeek from dual;
	select  
	case when vSAPPostingdate between to_date('20221226','YYYYMMDD')and to_date('20230101','YYYYMMDD') then '22' 
	when vSAPPostingdate <= to_date('20221226','YYYYMMDD') then to_char(vSAPPostingdate+7,'YY') else to_char(vSAPPostingdate,'YY') end
	into vYear from dual;
	if vGli_Process in ('GL-ISSUEFUEL','GL-ISSUEFUELCRD') then
	   vRef1 := substr(vMonth||'-'||vYear||' Week ' ||vWeek ||' - '||r_cre.dep_desc, 1,40);
	else
	   vRef1 := substr('IF-COR '|| vGli_Cre_Segment2,1,40);
	end if;
      
    r5o7.o7maxseq(vTransID,'GLI', '1', chk );
	insert into r5glinterface
	(GLI_TRANSID,GLI_RUNID,GLI_ENTRYID,GLI_SEQNUM,
	GLI_PROCESS,GLI_GROUP,GLI_STATUS,GLI_CREATEDBY,GLI_ACTUALFLAG,GLI_USERJECATEGORYNAME,GLI_USERJESOURCENAME,
	GLI_ACCOUNTINGDATE,GLI_TRANSACTIONDATE,GLI_DATECREATED,
	GLI_SETOFBOOKSID,GLI_CURRENCYCODE,
	GLI_SEGMENT1,GLI_SEGMENT2,GLI_SEGMENT3,GLI_SEGMENT4,
	GLI_ENTEREDDR,GLI_ENTEREDCR,
	GLI_REFERENCE1,GLI_ATTRIBUTE1,GLI_ATTRIBUTE2,GLI_ATTRIBUTE3,GLI_ATTRIBUTE4,GLI_ATTRIBUTE5,GLI_ATTRIBUTE6,GLI_GLNOMACCT,
	GLI_ORG)
	VALUES
   (vTransID,vRunID,vEntryID,vXMLSeqNum,
	vGli_Process,1,'NEW',1,'A','RFBU','GAMA',
	r_cre.fli_udfdate01,r_cre.fli_udfdate01,sysdate,
	vBookid,vOrgCurr,
	NULL,vGli_Cre_Segment2,vGli_Cre_Segment3,vGli_Cre_Segment4,
	NULL,
--round(abs(r_cre.fcost),2),
	vCreTotalCost,
	vRef1,r_cre.compc,vGrpCode,vAlloc,r_cre.fqty,vGLLinenumber,vGrpCode,vGli_Cre_glnomacct,
	r_cre.dep_org
   );         
     
   --Get group credit total cost and avg price
   if vCreTotalQty > 0 then
	vCreAvgPrice := abs(r_cre.fcost)/vCreTotalQty;
    update r5fuelissues
    set fli_udfnum02 = vCreAvgPrice,
	    fli_udfnum03 = vCreTotalQty
    where fli_code = vGrpCode;
   end if;
end loop;
   
update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
end if; --ucd.ucd_id = 7 and ucd.ucd_recalccost = '+'

exception when others then 
  null;
end;