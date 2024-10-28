select rowid from r5toolusage tou 
where tou.rowid=:rowid 
and exists (select 1 from r5tools where too_code = tou_tool and too_class is not null and  too_class not in ('N') and too_org  in ('ALC','PKM','SYN','BPK'))