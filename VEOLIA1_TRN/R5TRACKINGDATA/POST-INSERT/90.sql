DECLARE
tkd       r5trackingdata%rowtype;

vDue      date;
vOutWO    r5events.evt_code%type;
chk       varchar2(4);
vCnt      number;
iErrMsg   varchar2(400);
val_err   exception;

begin

  select * into tkd from r5trackingdata where rowid =:rowid;
  if tkd.tkd_trans = 'MPOA' then
      if tkd.tkd_promptdata6 is not null then
         begin
            vDue:=to_date(tkd.tkd_promptdata6,'YYYY-MM-DD');
         exception when others then
            iErrMsg := 'Due Date format is not correct, please use YYYY-MM-DD';
            raise val_err;
         end;
      end if;
      
      o7crevt8 (
         null,--event,
         tkd.tkd_promptdata1, --mp,
         tkd.tkd_promptdata2, --mporg,
         tkd.tkd_promptdata3, --revision
         tkd.tkd_promptdata4, --obj,
         tkd.tkd_promptdata5, --objorg,
         vDue, --due,
         tkd.tkd_promptdata7,--meterdue,
         null,               --meterdue2
         tkd.tkd_promptdata8, -- initseq,
         tkd.tkd_promptdata9, --eamuser
         vOutWO,
         chk);
         
     if chk in ('0') then
        UPDATE r5patternequipment
        SET    peq_status = 'A'
        WHERE  peq_mp         = tkd.tkd_promptdata1
        AND    peq_mp_org     = tkd.tkd_promptdata2
        AND    peq_revision   = tkd.tkd_promptdata3
        AND    peq_object     = tkd.tkd_promptdata4
        AND    peq_object_org = tkd.tkd_promptdata5;
     else
       begin 
         select etv_text into iErrMsg from r5errortext where etv_source = 'O7CREVT8' and etv_number = chk;
         iErrMsg := chk ||'-'||iErrMsg;
         raise val_err;
       exception when no_data_found then
          iErrMsg := chk;
           raise val_err;
       end;
     end if;
     
      o7interface.trkdel(tkd.tkd_transid);
     
  end if;
  

EXCEPTION
  when no_data_found then 
    null;
   WHEN val_err THEN
   RAISE_APPLICATION_ERROR(-20003, iErrMsg);
   WHEN OTHERS then
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/90/' ||SQLCODE || SQLERRM) ;
END;