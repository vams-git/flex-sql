select rowid
from r5bookedhours b
where b.rowid=:rowid
and   b.boo_octype ='C'
and exists (select 1 from r5events where evt_code = boo_event and evt_org in ('NVE','NVP','NVW'))
and (abs(b.boo_hours) < 2)