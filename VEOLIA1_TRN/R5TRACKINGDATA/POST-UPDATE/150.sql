declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  vNewStatus    r5invoices.inv_status%type;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
   /*******************************
   tkd_promptdata1 - status
   tkd_promptdata2 - org
   tkd_promptdata3 - service request
   tkd_promptdata4 - document code
   tkd_promptdata5 - ion interface monitor id
   tkd_promptdata6 - new doucment code
   tkd_promptdata7 --inf_status
   tkd_promptdata8 --inf_message
   ************************************/
  if tkd.tkd_trans = 'IU01' and tkd.tkd_promptdata1 = 'Process' then
     begin
       --update ion interface status
       update u5ionmonitor 
       set ion_status = tkd.tkd_promptdata7,ion_message = tkd.tkd_promptdata8
       where ion_transid = tkd.tkd_promptdata5;
       
       --update r5document reference code and interface flag for URL document
       update r5documents
       set doc_udfchar04 = tkd.tkd_promptdata6,doc_udfchkbox01 ='-'
       where doc_code = tkd.tkd_promptdata4;
       --update r5document reference code for new doucment code
       update r5documents 
       set doc_udfchar04 = tkd.tkd_promptdata4
       where doc_code = tkd.tkd_promptdata6;
       
       --assocation entity 
       insert into r5docentities
       (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo，dae_printonwo,dae_idmcopy)
       select tkd.tkd_promptdata6,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,'+'
       from r5docentities 
       where dae_document = tkd.tkd_promptdata4;
       --delete url association
       delete from r5docentities where dae_document = tkd.tkd_promptdata4;
       
        --delete from r5trackingdata where rowid=:rowid;
       o7interface.trkdel(tkd.tkd_transid);

     exception when err_val then
        RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
     end;
         
     
   
  end if;
  
exception
  when no_data_found then 
    null;
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/140/' ||SQLCODE || SQLERRM) ;
end;
