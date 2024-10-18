declare 
 kph         r5kpihistory%rowtype;
 cpk         number;
 cmail       r5mailtemplate.mat_code%type;
 vOrgReceipt r5mailevents.mae_emailrecipient%type;
 
 cursor cur_sttku is 
 select * from r5transactions WHERE tra_type ='STTK' and tra_status not in ('A','C') AND EXISTS (SELECT 1 FROM R5ORGANIZATION WHERE ORG_CODE = TRA_ORG AND ORG_LOCALE ='NZ');
begin
 select * into kph from r5kpihistory where rowid =:rowid;
 if kph.kph_value > 0 and kph.kph_homcode like 'K-STTK-U' then
    cmail := 'M-AUS-STTKU';
    begin
          select maa.maa_pk into cpk from r5mailattribs maa where maa.maa_template = cmail and maa.maa_table ='R5TRANSACTIONS';
    exception when no_data_found then
          return;
    end;
 
    for rec_tra in cur_sttku loop
        select  
        case when rec_tra.tra_org = 'STA' then 'dan.yakas@veolia.com'
             when rec_tra.tra_org = 'SWP' then 'chris.rutherford@veolia.com'
             when rec_tra.tra_org = 'WSL' then 'brad.laughton@veolia.com'
             when rec_tra.tra_org = 'RUA' then 'david.neru@veolia.com'
             when rec_tra.tra_org = 'QTN' then 'ash.smith@veolia.com'
             when rec_tra.tra_org = 'THC' then 'allan.hughes@veolia.com'
             when rec_tra.tra_org = 'WAN' then 'dan.yakas@veolia.com'
             when rec_tra.tra_org = 'CHB' then 'alex.horne@veolia.com'
             when rec_tra.tra_org = 'DOC' then 'david.neru@veolia.com'
             when rec_tra.tra_org = 'WEW' then 'alex.phelan@veolia.com'
             else null end into vOrgReceipt
        from dual;
        
        insert into r5mailevents
        (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
        MAE_PARAM1,--tra_code
        MAE_PARAM2,--tra_org
        MAE_PARAM3,--tra_fromcode
        MAE_PARAM4,--org_receipt
        MAE_PARAM5,--tra_createdby
        MAE_PARAM6,--tra_code
        MAE_PARAM7,--tra_desc
        MAE_PARAM8,--tra_created
        MAE_PARAM9,--tra_fromcodeDESC
        MAE_PARAM10,--tra_statusDESC,
        MAE_PARAM14,--ALLGOOD
        MAE_PARAM15,--:mp5user
        MAE_ATTRIBPK)
        VALUES
        (S5MAILEVENT.NEXTVAL,cmail,SYSDATE,'-','N',
         rec_tra.tra_code,
         rec_tra.tra_org,
         rec_tra.tra_fromcode,
         vOrgReceipt,
         rec_tra.tra_udfchar01,
         rec_tra.tra_code,
         rec_tra.tra_desc,
         TO_CHAR(rec_tra.tra_created,'DD-Mon-YYYY'),
         r5o7.o7get_desc('EN','STOR',rec_tra.tra_fromcode,'', ''),
         r5o7.o7get_desc('EN','UCOD',rec_tra.tra_status,'DOST', ''),
         '-',
         'R5',
          cpk--277--cpk--189
        );

    end loop;
 end if;
 
--exception 
--when others then
--RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5kpihistory/Post Insert/20');
end;