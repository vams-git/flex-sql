declare 
  evt               r5events%rowtype; 
  vAckSeqs          varchar2(2000); 
  vAckSeqsMsg       varchar2(2000); 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  /*cursor cur_ackact(iEvtCode varchar2) is
  select distinct ack_act 
  from r5actchecklists
  where ack_event =iEvtCode;*/
  cursor cur_ackact(iEvtCode varchar2) is
  select distinct ack_act
  from  r5events,r5activities,r5tasks,r5actchecklists
  where evt_code = act_event
  and   act_event = ack_event and act_act = ack_act
  and   act_task = tsk_code
  and   ack_event =iEvtCode
  and   (
  (evt_org not in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW') and instr(nvl(tsk_udfchar02,'48MR,65RP,35SB,50SO,51SO,52DT'),evt_status) > 0)
  or (evt_org in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW') and instr('49MF,50SO',evt_status) > 0 )
  )
  ;
  
  cursor cur_ack(iEvtCode varchar2,iAct varchar2) is
  select ack_act,ack_sequence
  from r5actchecklists
  where ack_event =iEvtCode
  and ack_act = iAct
  and
  (
   (ack_requiredtoclose ='YES' and
    ((ack_type ='01'and (nvl(ack_completed,'-')='-' or ack_notes is null))
    or (ack_type='02' and nvl(ack_yes,'-')||nvl(ack_no,'-')='--' )
    or (ack_type='03' and ack_finding is null)
    or (ack_type='04' and ack_value is null)
    or (ack_type='05' and ack_value is null)
    or (ack_type='06' and ack_finding is null)
    )
    )
   or
   (ack_type='03' and ack_finding='OTHE' and ack_notes is null)
  )
  order by ack_act,ack_sequence;
  
  cursor cur_ack_tas(iEvtCode varchar2,iAct varchar2) is
  select ack_act,ack_sequence
  from r5actchecklists ack
  where ack_event =iEvtCode
  and ack_act = iAct
  and
  (
   (ack_requiredtoclose ='YES' and
    ((ack_type ='01'and (nvl(ack_completed,'-')='-') and ack.ack_not_applicable is null)
    or (ack_type='02' and nvl(ack_yes,'-')||nvl(ack_no,'-')='--' and ack.ack_not_applicable is null )
    or (ack_type='03' and ack_finding is null and ack.ack_not_applicable is null)
    or (ack_type='04' and ack_value is null and ack.ack_not_applicable is null)
    or (ack_type='05' and ack_value is null and ack.ack_not_applicable is null)
    or (ack_type='06' and ack_finding is null and ack.ack_not_applicable is null)
    )
    )
  )
  order by ack_act,ack_sequence;
begin
  
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
    --IF evt.EVT_STATUS IN ('48MR','65RP','35SB','50SO','51SO','52DT') THEN
      for rec_ackact in cur_ackact(evt.evt_code) LOOP
        if evt.evt_org not in ('TAS','VIC','WAU','NWA','WAR','SAU','NSW','QLD','NTE','NVE','NVP','NVW') then
          for rec_ack in cur_ack(evt.evt_code,rec_ackact.ack_act) LOOP
            vAckSeqs :=vAckSeqs||rec_ack.ack_sequence||',';
          end loop;
        else
          for rec_ack_tas in cur_ack_tas(evt.evt_code,rec_ackact.ack_act) LOOP
            vAckSeqs :=vAckSeqs||rec_ack_tas.ack_sequence||',';
          end loop;
        end if;
        if vAckSeqs is not null then
          vAckSeqs := substr(vAckSeqs,1,length(vAckSeqs)-1);
          vAckSeqsMsg := vAckSeqsMsg ||vAckSeqs || '(on Activity '|| rec_ackact.ack_act  || ') ';
        end if;
      end loop;
        
        if vAckSeqsMsg is not null then
          iErrMsg := 'Please note the WO status cannot be changed until all mandatory checklist questions have been answered. '
          ||'Please answer the following questions '||vAckSeqsMsg|| ' or filled the matching notes when appropriate.';
          raise err_chk; 
        end if;
      --END IF;
  end if; 
  
EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5EVENTS/200/U - '||iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( -20003,'ERR/R5EVENTS/200/U - '||substr(SQLERRM, 1, 500)) ;
end;