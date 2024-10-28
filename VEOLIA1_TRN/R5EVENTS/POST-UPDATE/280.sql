declare
  rEvt        r5events%rowtype;
  VCORRACT    VARCHAR2(255);
  CEVTSTATVAL VARCHAR2(255);
  obj         r5objects%rowtype;
  ceventno    r5events.evt_code%type;
  V_STW_TEM   R5STANDWORKS.STW_CODE%TYPE;
  V_STW_CHK   VARCHAR2(3);
  vWOFirstAct VARCHAR2(255);
  chk         varchar2(3);
  vDateTime   date;
  vDate       date;
  vMailTemp   r5mailtemplate.mat_code%type;
  vFollowMRC  r5events.evt_mrc%type;
  vCount      number;
  vNotes      r5actchecklists.Ack_Notes%type;
  vWODesc     r5events.evt_desc%type;
  vWOStatus   r5events.evt_status%type;
  iErrMsg     varchar2(400);
  err_val     exception;
  
  cursor cur_followupevt(vEvt varchar2) is
    select distinct ack_event, ack_act, substr(ack_notes,1,80)
    as ack_wodesc, ack_notes, ack_code, ack_object, ack_object_org
    from r5activities, r5actchecklists, r5tasks
    where act_event = ack_event and act_act = ack_act
      and ack_event = vEvt and ack_followup ='+'
      and ack_followupevent is null and act_task = tsk_code
      and act_taskrev = tsk_revision and tsk_class = 'CORR'
      and ack_sequence = 50;
  
  cursor cur_origcomment(vEvt varchar2) is
    select * from r5addetails
    where add_entity='EVNT' and add_code = vEvt
    order by add_line;

begin
  --evt_code
  select * into rEvt from r5events where rowid=:rowid;
  -- check org is CORRACT setup
  BEGIN
    SELECT NVL(OPA_DESC, 'NO') INTO VCORRACT
    FROM R5ORGANIZATIONOPTIONS
    WHERE OPA_ORG = rEvt.evt_org AND OPA_CODE = 'CORRACT';
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      VCORRACT :='NO';
      RETURN;
  END;
  
  if VCORRACT != 'NO' then
    CEVTSTATVAL := NVL((REGEXP_SUBSTR(VCORRACT,
    '\{{VAL:([^}]+)\}}', 1, 1, NULL, 1)), '50SO,51SO');
  else
    CEVTSTATVAL := '50SO,51SO';
  end if;
  
  if VCORRACT != 'NO' AND  INSTR(CEVTSTATVAL, rEvt.Evt_Status) != 0 then
    vDateTime := o7gttime(rEvt.evt_org);
    vDate := trunc(o7gttime(rEvt.evt_org));
    vMailTemp := 'M-'||rEvt.evt_org ||'-PMERROR';
    
    begin
      select ack_notes into vNotes
      from r5activities, r5actchecklists, r5tasks
      where act_event = ack_event and act_act = ack_act
        and ack_event = rEvt.evt_code
        and act_task = tsk_code
        and act_taskrev = tsk_revision
        and tsk_class = 'CORR'
        and ack_sequence = 51
        and ack_yes = '+';
      
      if vNotes is null then
        iErrMsg := 'Note is mandatory for Checklist Sequence 51';
        raise err_val;
      else
        select count(1) into vCount
        from r5mailevents
        where MAE_TEMPLATE = vMailTemp --'M-HWC-PMERROR'
          and MAE_PARAM2 = rEvt.evt_code;
          
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
              MAE_PARAM11,--Position
              MAE_PARAM13,--Priority
              MAE_PARAM15,MAE_ATTRIBPK)
          values
            (S5MAILEVENT.NEXTVAL,vMailTemp,SYSDATE,'-','N',
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
              o7sess.cur_user,0);
        end if;
      end if;
    exception when no_data_found then
      iErrMsg := null;
    end;
    
    for rec_fwo in cur_followupevt(rEvt.Evt_Code) loop
      if rec_fwo.ack_wodesc is null then
        iErrMsg := 'Note is mandatory for Checklist Sequence 50';
        raise err_val;
      end if;
      
      r5o7.o7maxseq( ceventno, 'EVENT', '1', chk );
      select * into obj from r5objects where obj_code = rec_fwo.ack_object and obj_org = rec_fwo.ack_object_org;
      
      vWODesc:= substr(rec_fwo.ack_wodesc,1,80); 
      
      if rEvt.evt_org in ('HWC','KUR') then 
        vFollowMRC := rEvt.evt_org || '-MT';
      else
        vFollowMRC := obj.obj_mrc;
      end if;
      
      vWOStatus := NVL((REGEXP_SUBSTR(VCORRACT,
        '\{{REL:([^}]+)\}}', 1, 1, NULL, 1)), '15TV');
      
      insert into r5events
        (EVT_ORG,EVT_CODE,EVT_TYPE,EVT_RTYPE,EVT_MRC,EVT_LTYPE,EVT_LOCATION,EVT_LOCATION_ORG,EVT_COSTCODE,EVT_PROJECT,EVT_PROJBUD,EVT_OBTYPE,EVT_OBJECT,EVT_OBJECT_ORG,EVT_ISSTYPE,EVT_FIXED,
          EVT_DATE,EVT_TARGET,EVT_SCHEDEND,EVT_DURATION,EVT_REPORTED,EVT_ENTEREDBY,EVT_CREATED,EVT_CREATEDBY,
          EVT_ORIGWO,EVT_ORIGACT,EVT_DESC,EVT_JOBTYPE,EVT_CLASS,EVT_CLASS_ORG,EVT_STATUS,EVT_PRIORITY,
          evt_udfchar27,evt_udfchar29)
      VALUES
        (rEvt.EVT_ORG,ceventno,'JOB','JOB',vFollowMRC,rEvt.EVT_LTYPE,obj.obj_location,obj.OBJ_LOCATION_ORG,obj.obj_costcode,rEvt.EVT_PROJECT,rEvt.EVT_PROJBUD,obj.OBJ_OBTYPE,obj.OBJ_CODE,obj.OBJ_ORG,'F','V',
          vDateTime,vDate,vDate,1,vDateTime,o7sess.cur_user,vDateTime,o7sess.cur_user,
          rEvt.EVT_CODE,rec_fwo.ack_act,vWODesc,'RQ','CO','*',vWOStatus,null,
          rEvt.evt_code,vFollowMRC);
      
      o7creob1( ceventno, 'JOB', obj.obj_code, obj.obj_org, obj.obj_obtype, obj.obj_obrtype, chk );
      o7descs( 'UPD', null, 'EVNT', null, '*', ceventno, rEvt.EVT_ORG,vWODesc, chk);

      BEGIN
        SELECT NVL(STW_CODE, 'NO') INTO V_STW_TEM
        FROM R5STANDWORKS
        WHERE STW_CLASS = 'DEFSTW' AND STW_TYPE = 'SWO'
          AND NVL(STW_NOTUSED,'-') = '-'
          AND STW_ORG = rEvt.EVT_ORG
          AND STW_JOBTYPE = 'RQ'
          AND (SELECT COUNT(1) FROM R5STANDWACTS WHERE WAC_STANDWORK = STW_CODE) > 0;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
        V_STW_TEM :='NO';
      END;
      
      if V_STW_TEM = 'NO' then
        insert into r5activities
          (act_event,act_act,act_start,act_time,act_hire,act_ordered,act_fixh,act_minhours,
            act_mrc,act_trade,act_persons,act_project,act_projbud,
            act_duration,act_est,act_rem,act_nt,act_ntrate,act_ot,act_otrate,
            act_special,act_completed,act_qty,
            act_task,act_taskrev,act_note,act_planninglevel)
        values
          (ceventno,10,vDate,'1','-','-','-','-',
            rEvt.EVT_MRC,'*',1,rEvt.evt_project,rEvt.evt_projbud,
            '1',1,'0','0','0','0','0',
            '-','-',1,
            null,null,rec_fwo.ack_notes,'TP');
        vWOFirstAct := 10;
      ELSE
        SELECT * INTO vWOFirstAct FROM (SELECT WAC_ACT FROM R5STANDWACTS WHERE WAC_STANDWORK = V_STW_TEM ORDER BY WAC_ACT ASC) WHERE ROWNUM = 1;
      end if;
      
      update r5actchecklists
      set ack_followupevent = ceventno,
          ack_followupact = vWOFirstAct
      where ack_code = rec_fwo.ack_code;
      
      for rec_wocomm in cur_origcomment(rEvt.Evt_Code) loop
        insert into r5addetails
          (add_entity,add_rentity,add_type,add_rtype,add_code,add_lang,add_line,add_print,add_text,
            add_created,add_user)
        values
          (rec_wocomm.add_entity,rec_wocomm.add_rentity,rec_wocomm.add_type,rec_wocomm.add_rtype,ceventno,rec_wocomm.add_lang,rec_wocomm.add_line,rec_wocomm.add_print,rec_wocomm.add_text,
            vDateTime,o7sess.cur_user);
      end loop;
      
    end loop;
    
  end if;
EXCEPTION
when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5EVENTS/280/U/ '||iErrMsg) ;
when others then
   RAISE_APPLICATION_ERROR ( -20003,'ERR/R5EVENTS/280/U/ '||substr(SQLERRM, 1, 500)) ; 
end;