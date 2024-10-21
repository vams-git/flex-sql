select rowid
from r5bookedhours b
where b.rowid=:rowid
and   b.boo_octype ='C'
and exists (select 1 from r5events where evt_code = boo_event and evt_org in ('VIC','WAU','WAR','NWA','SAU'))
and (
(
boo_correction='-' and
(select sum(boo_hours)
from r5bookedhours b2 where b2.boo_person = b.boo_person
and b2.boo_date = b.boo_date
and b2.boo_octype = b.boo_octype) <> 4
)
or
(
boo_correction='+' and
(select sum(boo_hours)
from r5bookedhours b2 where b2.boo_person = b.boo_person
and b2.boo_date = b.boo_date
and b2.boo_octype = b.boo_octype) <> 0
)
)
