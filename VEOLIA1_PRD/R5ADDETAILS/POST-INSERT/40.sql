declare
   rec_adddetails r5addetails%rowtype;
   vText          varchar2(4000);
   vEvent         r5activities.act_event%type;
   vOrg           r5organization.org_code%type;
   vCount         number;
   vLine          r5addetails.add_line%type;
   
   vDocCode       r5documents.doc_code%type;
   vFileName      r5documents.doc_filename%type;
   vCOCTCode      r5addetails.add_code%type;
   vURL           varchar2(4000);       
   vPrefix        r5documents.doc_origfilename%type;
   
   vInfTime       date;
   vCOCT          r5contactrecords.ctr_code%type; 
   vTransID       r5trackingdata.tkd_transid%type;
   chk            varchar2(3);
   vCnt           number;
   

begin
    select * into rec_adddetails
    from r5addetails
    where rowid=:rowid; 
    --where add_code  = '15478#WBP';
    
   /* if rec_adddetails.add_rentity = 'COCT' and rec_adddetails.add_code like '%WBP' then
      vText := R5REP.TRIMHTML(rec_adddetails.add_code,rec_adddetails.add_rentity,rec_adddetails.add_type,rec_adddetails.add_lang,rec_adddetails.add_line); 
      if vText like 'Client WorkDetails:%' then
        begin
         select ctr_event,ctr_org into vEvent,vOrg
         from r5contactrecords where ctr_code||'#'||ctr_org = rec_adddetails.add_code
         and ctr_event is not null and ctr_copynotetowo = '+' and ctr_note is not null;

         update r5addetails 
         set add_text = vText,
         add_updated = o7gttime(vOrg)
         where add_entity = 'EVNT' and add_type = '*' and add_line = 10
         and add_code = vEvent;
         
          --check min client work details
          select count(add_line),min(add_line) into  vCount,vLine
          from r5addetails 
          where  add_rentity = rec_adddetails.add_rentity and add_type = rec_adddetails.add_type
          and    add_code = rec_adddetails.add_code
          and    R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)
              like 'Client WorkDetails:%';
          if vCount > 1 then
             update r5addetails 
             set add_text = vText,
             add_updated = o7gttime(vOrg)
             where add_rentity = rec_adddetails.add_rentity and add_type = rec_adddetails.add_type
             and   add_code = rec_adddetails.add_code
             and   add_line = vLine; 
             delete from r5addetails where rowid=:rowid; 
          end if;
        exception when no_data_found then
          null;
        end; 
        
      end if;  
      
    end if;*/
    
    if rec_adddetails.add_rentity = 'COCT' and rec_adddetails.add_code like '%QTN' then --and rec_adddetails.add_line = 10  then
        begin
          vPrefix := 'Link(s) provided by the client. Please click to visualize documentation provided:';
          vText := R5REP.TRIMHTML(rec_adddetails.add_code,rec_adddetails.add_rentity,rec_adddetails.add_type,rec_adddetails.add_lang,rec_adddetails.add_line); 
          select ctr_event,ctr_org into vEvent,vOrg
          from r5contactrecords where ctr_code||'#'||ctr_org = rec_adddetails.add_code
          and ctr_event is not null;
          
          if instr(vText,vPrefix) > 0 then
             vDocCode := s5docs.nextval;
             vCOCTCode := replace(rec_adddetails.add_code,'#QTN',null)||'_'||to_char(rec_adddetails.add_line);
             vURL := replace(vText,vPrefix,null);
             vURL := substr(vURL,instr(vURL,'http'));
             vURL:=replace(vURL,CHR(10),null);
             vURL:=replace(vURL,CHR(13),null);
             vFileName:=substr(vURL,1,255);
             insert into r5documents
             (DOC_CODE,DOC_DESC,DOC_FILENAME,DOC_ORG,DOC_TYPE,DOC_RTYPE,DOC_NOTUSED,DOC_ORIGFILENAME,DOC_UPLOADED,DOC_EXCLUDEPMWORKORDER,
             DOC_WARRANTY,DOC_CREATEDBY,DOC_CREATED,
             DOC_UDFCHAR04,DOC_UDFCHKBOX05
             )
             values
             (vDocCode,vCOCTCode,vFileName,'QTN','F','F','-',vFileName,rec_adddetails.add_created,'+',
             '-',
             O7SESS.CUR_USER,o7gttime('QTN'),
             null,'+');     

             insert into r5addetails
             (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text)
             values
             ('DOCU','DOCU','*','*',vDocCode,'EN',10,'+',vURL);
             
             insert into r5docentities
             (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo)
             values
             (vDocCode,'COCT','COCT','*','*',rec_adddetails.add_code,'+','+');
              insert into r5docentities
             (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_printonwo)
             values
             (vDocCode,'EVNT','EVNT','*','*',vEvent,'+');
             
              --insert u5ionmonitor 
              vCOCT := replace(rec_adddetails.add_code,'#QTN',null);
              vInfTime := sysdate;
              r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk);
              insert into U5IONMONITOR
             (ION_TRANSID,ION_SOURCE,ION_DESTINATION,ION_TRANS,ION_REF,ion_xmlseqno,
              ION_ORG,ION_KEYFLD1,ION_KEYFLD2,ION_KEYFLD3,ION_KEYFLD4,ION_KEYFLD5,ION_DATA,
              ION_CREATE,ION_STATUS,ION_SENDEMAIL,UPDATECOUNT,CREATED,CREATEDBY)
              values
              (vTransID,'QTN','EAM','DOC',null,null,
               'QTN',vCOCT,vDocCode,null,null,null,vURL,
                vInfTime,'New','-',0,trunc(vInfTime),O7SESS.cur_user
              );
             
              --insert tracking data for update message and relink new downloaded doc_code with entity
              insert into r5trackingdata
              (tkd_created,tkd_trackdate,tkd_sourcesystem,tkd_sourcecode,tkd_trans,
              tkd_promptdata1,tkd_promptdata2,tkd_promptdata3,tkd_promptdata4,tkd_promptdata5)
              values
              (vInfTime,vInfTime,'QTN',vDocCode,'IU01',
              'New','QTN',vCOCT,vDocCode,vTransID);
          else
              select count(add_line),min(add_line) into vCount,vLine
              from r5addetails 
              where  add_rentity = 'EVNT' and add_type = '*'
              and    add_code = vEvent
              and    R5REP.TRIMHTML(add_code,add_rentity,add_type,add_lang,add_line)
              like   vText || '%';
              if vCount = 0 then
                 --geting count of work order comments
                 select count(1) into vCnt 
                 from   r5addetails 
                 where  add_rentity = 'EVNT' and add_type = '*'
                 and    add_code = vEvent;
                 
                 insert into r5addetails
                 (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,add_created)
                  values
                 ('EVNT','EVNT','*','*',vEvent,'EN',vCnt + 1,'+',vText,o7gttime(vOrg));
              end if;
           end if;  
        exception when no_data_found then
            null;
        end;
    end if;    
    
 end;