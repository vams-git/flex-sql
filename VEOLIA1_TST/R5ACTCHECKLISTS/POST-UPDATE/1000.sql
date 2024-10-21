select 1 from
r5events,r5activities,r5actchecklists ack,r5tasks
where  evt_code = act_event 
and    act_event = ack_event and act_act = ack_act
and    act_task = tsk_code and act_taskrev = tsk_revision and tsk_class = 'CORR'
and    evt_org in ('WYU','HWC','KUR','BAL','TAS','VIC','WAU','WAR','NWA','NSW','SAU','QLD','NTE','NVE','NVP','NVW')
and    ack_yes = '+' and ack_sequence = 50 and (ack_notes is null or ack_notes='')
and    ack.rowid=:rowid;