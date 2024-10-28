select rowid from r5addetails
where add_entity ='EVNT' and add_code like '%#%'
and   (select usr_group from r5users where usr_code = add_user) in ('VIS-MS','VIS-OP')
and   rowid =:rowid;