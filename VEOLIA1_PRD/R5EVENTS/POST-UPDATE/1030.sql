select 1 from
r5events evt,r5organization org
where 
evt_org = org_code
and ( 
(evt_org in ('WRR') and evt_class not in ('PS','BD','CO','OP','RF','RN'))
or (evt_org in ('QGC') and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD','EQ','SE','DC'))
or (evt_org in ('HWC') and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD','DC'))
or (evt_org in ('STA') and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD'))
or (evt_org in ('BAR') and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD','SE','DC'))
or (evt_org in ('PKM') and evt_class not in ('PS','PW','UW','PN','UN'))
or (evt_org in ('ALC','BPK','BRK','MMO','SYN') and evt_class not in ('PS','OP','SE','PR','PW','UW','MA','ST','EM','SC'))
or (evt_org in ('ACW','NWA','TAS','VIC','WAR','WAU','SAU','NSW','QLD','NTE','NVE','NVP','NVW') and evt_class not in ('PS','CO','BD','RF','OP'))
or (org_curr = 'NZD' and evt_org not in ('STA','ACW') 
    and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD'))
or (org_curr = 'AUD' and evt_org not in ('WRR','QGC','HWC','BAR','PKM','ALC','BPK','BRK','MMO','SYN','NWA','TAS','VIC','WAR','WAU','SAU','NSW','QLD','NTE','NVE','NVP','NVW') 
    and evt_class not in ('PS','CN','CO','MO','RF','RN','OP','BD','SE','DC'))
)
and    evt.rowid=:rowid;