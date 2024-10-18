declare 
   rEvt r5events%rowtype;
   obj  r5objects%rowtype;
   ceventno    r5events.evt_code%type;
   chk         varchar2(3);
   vCount      number;
   vNotes      r5actchecklists.Ack_Notes%type;
   iErrMsg     varchar2(400);
   err_val     exception;
    

begin
   select * into rEvt from r5events where rowid=:rowid;--evt_code ='1005050890';--
   if rEvt.evt_org in ('QTN') and rEvt.Evt_Status  ='49MF' then    
       begin 
         select count(1) into vCount--ack_notes into vNotes 
         from r5activities,r5actchecklists
         where act_event = ack_event and act_act = ack_act
         and   ack_event = rEvt.evt_code  
         and   ack_sequence = 205000
         and   ack_yes = '+'
         and   ack_notes is null;
         
         if vCount > 0 then 
            iErrMsg := 'Note is mandatory for Checklist Sequence 205000';
            raise err_val;
         end if;
         
         select count(1) into vCount--ack_notes into vNotes 
         from r5activities,r5actchecklists
         where act_event = ack_event and act_act = ack_act
         and   ack_event = rEvt.evt_code  
         and   ack_sequence = 205000
         and   ack_yes = '+';
         if vCount > 0 then
           select count(1) into vCount
           from r5mailevents
           where MAE_TEMPLATE = 'M-'||rEvt.evt_org||'-PMERROR'
           and   MAE_PARAM2 = rEvt.evt_code;
           if vCount = 0 then
               insert into r5mailevents
              (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
               MAE_PARAM1,--org
               MAE_PARAM2,--wo
               MAE_PARAM3,--wo desc
               MAE_PARAM4,--element
               MAE_PARAM6,--WO Class
               MAE_PARAM7,--Status
               MAE_PARAM8,--Site
               MAE_PARAM9,--Unit
               MAE_PARAM10,--Tag Code
               MAE_PARAM11,--Poistion
               MAE_PARAM13,--Priority
               MAE_PARAM15,MAE_ATTRIBPK) 
              values
              (S5MAILEVENT.NEXTVAL,'M-'||rEvt.evt_org||'-PMERROR',SYSDATE,'-','N',
               rEvt.evt_org,
               rEvt.evt_code,
               rEvt.evt_desc,
               rEvt.evt_object,
               rEvt.evt_class,
               r5o7.o7get_desc('EN','UCOD',rEvt.evt_status,'EVST', ''),
               rEvt.evt_udfchar04,
               rEvt.evt_udfchar08,
               (select obj_udfchar15 from r5objects where obj_code = rEvt.evt_object and obj_org = rEvt.evt_object_org),
               rEvt.evt_udfchar12,
               r5o7.o7get_desc('EN','UCOD',rEvt.Evt_Priority,'JBPR',''),
               o7sess.cur_user,
               0);
           end if;
         end if;
       exception when no_data_found then
         iErrMsg := null;
       end;
   end if;
EXCEPTION
when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/285/'||substr(SQLERRM, 1, 500)) ;  
end;
