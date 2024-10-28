declare
  ock           r5operatorchecklists%rowtype;
  obj           r5objects%rowtype;
  
  vCCopt        r5organizationoptions.opa_desc%type;
  vCCown        r5personnel.per_emailaddress%type;
  
  vPK           r5mailattribs.maa_pk%type;
  vMailTemp     r5mailtemplate.mat_code%type;
  vRecipient    r5mailevents.mae_emailrecipient%type;
  vCostCode     r5mailevents.mae_param1%type;
  vCostCenter   r5mailevents.mae_param1%type;
  vSAPComp      r5organization.org_udfchar09%type;
  vNote         r5mailevents.mae_param1%type;
  vRptUser      r5mailevents.mae_param15%type;
  
  vWODesc       r5events.evt_desc%type;
  ceventno      r5events.evt_code%type;
  vDateTime     date;
  vDate         date;
  chk           varchar2(3);
  vCnt          number;
  iErrMsg       varchar2(200);
  err           exception;
  
  cursor cur_opdoc(vOpCode varchar2,vOrg varchar2) is
    select ack.ack_code,dae.dae_document,doc.doc_code,
      ack.ack_sequence,ack.ack_finding,ack.ack_notes
    from  r5actchecklists ack,r5docentities dae,r5documents doc
    where ack_code = dae_code
      and   dae_document = doc_code
      and   dae_entity = 'OPCL'
      and   ack_rentity = 'OPCK'
      and   ack_entitykey = vOpCode
      and   ack_entityorg = vOrg;

begin
  select * into ock from r5operatorchecklists where rowid=:rowid; 
  
  begin
    select opa_desc into vCCopt from r5organizationoptions
    where opa_code ='CCOWNDVR' and opa_org = ock.ock_org;
  exception when no_data_found then 
    vCCopt :='NO';
  end;
  
  if vCCopt = 'YES' and ock.ock_status = 'C'
    and NVL(ock.ock_udfchkbox01,'-') = '-'
    and ock.ock_task in ('CAUS-CHK-T-1001','CAUS-CHK-T-0002') then
    if ock.ock_task = 'CAUS-CHK-T-1001' then
      vMailTemp := 'M-OPC-COMPDAILYVR';
      vRptUser := 'R5';
    end if;
    if ock.ock_task = 'CAUS-CHK-T-0002' then
      vRptUser := null;
      vMailTemp := 'M-OPC-COMP';
    end if;
    
    select * into obj from r5objects
    where obj_code = ock.ock_object 
      and obj_org = ock.ock_object_org;

      if NVL(obj.obj_driver,'X') != 'X' then
         select count(1) into vCnt from r5mailevents mae
         where mae.mae_param7 = ock.ock_code
         and   mae.mae_template = vMailTemp;
         if vCnt > 0 then
            return;
         end if;
         --insset email template start
         select org_udfchar09 into vSAPComp from r5organization where org_code = ock.ock_org;
         select per_emailaddress into vCCown from r5personnel where per_code = obj.obj_driver;
         
         vCostCode := replace(obj.obj_udfchar37,vSAPComp||'-CST-',null);
         vCostCenter := vCostCode ||'-'||r5o7.o7get_desc('EN','CSTC', obj.obj_udfchar37,'','');
         vRecipient := 'anz.vwa.aus.gamaadmin.int.groups@veolia.com afiq.rostam@veolia.com'; 
         if NVL(vCCown,'X') != 'X' then
          vRecipient := vRecipient || ' ' || vCCown; 
         end if;
        
         if ock.ock_udfchar02 is null then
            vNote:='No fault where found during that process.';
         else
            vNote:='Fault(s) where found during that process, please access VAMS for more details.';
         end if;
     
         select maa_pk into vPK from r5mailattribs  where maa_template = vMailTemp and maa_table = 'R5OPERATORCHECKLISTS';
     
         insert into r5mailevents
        (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
         MAE_PARAM1,--RECEIPTS
         MAE_PARAM2,--equipment
         MAE_PARAM3,--complete date
         MAE_PARAM4,--location desc
         MAE_PARAM5,--mrc desc
         MAE_PARAM6,--costcenter owner
         MAE_PARAM7,--opc code - linked with report
         MAE_PARAM8,--NOTES
         MAE_PARAM15,MAE_ATTRIBPK) 
        values
        (S5MAILEVENT.NEXTVAL,
         vMailTemp,
         SYSDATE,'-','N',
         vRecipient,
         obj.obj_desc,--equipment
         to_char(ock.ock_enddate,'DD-MON-YYYY'),--complete date
         r5o7.o7get_desc('EN','OBJ', obj.obj_location||'#'|| obj.obj_location_org,'', ''),--location desc
         r5o7.o7get_desc('EN','MRC', obj.obj_mrc,'', ''),--mrc desc,
         vCostCenter,--costcenter owner
         ock.ock_code,
         vNote,
         vRptUser,
         vPK);
         --insset email template end
         
      end if; --obj.obj_driver not null
      
      update r5operatorchecklists
      set    ock_udfchkbox01 = '+'
      where  ock_code = ock.ock_code;
  end if;

exception 
  when err then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5operatorchecklists/Post Update/50/'||substr(SQLERRM, 1, 500)) ; 
end;