select rowid 
from r5translines trl
where trl.rowid=:rowid
and   trl.trl_event is not null and trl.trl_type = 'I' and trl.trl_qty < 0
and   abs(trl.trl_qty)  >
(select case when sum(trl_qty) is null then 0 else sum(trl_qty) end
from   r5translines ti
where  ti.trl_event =trl.trl_event 
and    ti.trl_act = trl.trl_act
and    ti.trl_part = trl.trl_part
and    ti.trl_store = trl.trl_store
and    ti.trl_type  ='I'
and    rowid<>:rowid
)