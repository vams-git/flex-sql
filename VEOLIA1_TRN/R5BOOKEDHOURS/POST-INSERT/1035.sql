select rowid from r5bookedhours b where boo_octype not in ('N','NH','O','C') and  b.rowid=:rowid and exists (select 1 from r5events where evt_code = boo_event and evt_org in ('NSW'));