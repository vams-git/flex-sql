select rowid from r5events evt
where evt.rowid=:rowid
and   evt.evt_org in ('TAS','VIC','WAU','WAR','NWA','SAU','NSW','QLD','NTE','NVE','NVW','NVP')
and   evt.evt_status in ('49MF','50SO')
and exists
(
  select 1
  from r5actchecklists ack
  where ack_event =evt_code
  and
  (
   (ack_requiredtoclose ='YES' and
    ((ack_type ='01'and ack_completed ='-' and ack.ack_not_applicable is null)
    or (ack_type='02' and ack_yes||ack_no='--' and ack.ack_not_applicable is null)
    or (ack_type='03' and ack_finding is null and ack.ack_not_applicable is null)
    or (ack_type='04' and ack_value is null and ack.ack_not_applicable is null)
    or (ack_type='05' and ack_value is null and ack.ack_not_applicable is null)
    or (ack_type='06' and ack_finding is null and ack.ack_not_applicable is null) 
    )
    )
  )
)