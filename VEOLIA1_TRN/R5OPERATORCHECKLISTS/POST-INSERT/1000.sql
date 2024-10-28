select ock_code from r5operatorchecklists ock,r5objects,r5tasks
where ock_object = obj_code and ock_object_org = obj_org
and   ock_task = tsk_code and ock_taskrev = tsk_revision
and   obj_obtype in ('06EQ','07CP') and tsk_class = 'VCON'
and   ock.rowid=:rowid