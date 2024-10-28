declare 
  evt             r5events%rowtype;
  vCommentLong    long;
  vComment        varchar2(300);
  vRejReason      r5events.evt_rejectreason%type;
  vRejReasonLen   number;
  
  vMailTemp       r5mailtemplate.mat_code%type;
  vCnt            number;
  vPK             r5mailattribs.maa_pk%type;
  
  iErrMsg      varchar2(400);
  err_val      exception;


begin
    select * into evt from r5events where rowid=:rowid;--evt_code = '1005429161';--
    
    if evt.evt_type in ('JOB') and evt.evt_parent is null and evt.evt_status ='20RJ' then
        if evt.evt_rejectreason is null then
          begin
             select add_text into vCommentLong
             from r5addetails
             where add_entity='EVNT' and add_code=evt.evt_code and add_lang = 'EN' and add_line = 1;
             vComment := substr(vCommentLong,1,300);
           
             if vComment like 'Reject Reason Details%' then
                select 
                nvl(length(replace(replace(replace(vComment,'Reject Reason Details',''),':',''),' ','')),0) into vRejReasonLen
                from dual;    
             else 
                vRejReasonLen := 0;
             end if;
          exception when no_data_found THEN
            vRejReasonLen := 0;
          end;
            
          if vRejReasonLen = 0 then         
             iErrMsg :='Please enter Reject Reason Details in Comments.';
             raise err_val;
          else 
             vRejReason := substr(replace(replace(vComment,'Reject Reason Details',''),':',''),1,240);
             update r5events set evt_rejectreason = vRejReason 
             where evt_code = evt.evt_code and evt_rejectreason is null;
          end if;
       end if; --evt.evt_rejectreason is null 

       
       vMailTemp := 'M-AUS-WO-20RJ';
       select maa_pk into vPK from r5mailattribs  where maa_template = vMailTemp and maa_table = 'R5EVENTS';
       select count(1) into vCnt 
       from r5mailevents mae where mae.mae_template = vMailTemp and mae.mae_param2 = evt.evt_code;
       if vCnt = 0 then
          insert into r5mailevents
          (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
           MAE_PARAM1,--EVT_ENTEREDBY
           MAE_PARAM2,--EVT_CODE
           MAE_PARAM3,--EVT_DESC
           MAE_PARAM4,--EVT_OBJECT
           MAE_PARAM5,--EVT_OBJECT_ORG
           MAE_PARAM6,--EVT_CLASS
           MAE_PARAM7,--EVT_STATUS
           MAE_PARAM8,--EVT_REJECTREASON
           MAE_PARAM9,--EVT_UDFCHAR04
           MAE_PARAM10,--EVT_UDFCHAR08
           MAE_PARAM11,--EVT_UDFCHAR16
           MAE_PARAM12,--EVT_UDFCHAR12
           MAE_PARAM13,--EVT_UDFCHAR32
           MAE_ATTRIBPK) 
          values
          (S5MAILEVENT.NEXTVAL,
           vMailTemp,
           SYSDATE,'-','N',
           evt.EVT_ENTEREDBY,
           evt.EVT_CODE,
           evt.EVT_DESC,
           evt.EVT_OBJECT,
           evt.EVT_OBJECT_ORG,
           evt.EVT_CLASS,
           evt.EVT_STATUS,
           evt.EVT_REJECTREASON,
           evt.EVT_UDFCHAR04,
           evt.EVT_UDFCHAR08,
           evt.EVT_UDFCHAR16,
           evt.EVT_UDFCHAR12,
           evt.EVT_UDFCHAR32,
           vPK);
         end if;
    
  end if; -- evt.evt_type in ('JOB') and evt.evt_parent is null and evt.evt_status ='20RJ
    

exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
when others then 
  RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Insert/5/'||substr(SQLERRM, 1, 500));
end;
