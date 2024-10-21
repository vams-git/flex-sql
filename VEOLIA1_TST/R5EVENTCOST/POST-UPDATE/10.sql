declare 
  evo        r5eventcost%rowtype;
  err        exception;
  iErrMsg    varchar2(400);
begin
    select * into evo from r5eventcost where rowid= :rowid;
    if evo.evo_recalccost = '+' then
     /* Update record in r5eventcost. */
      UPDATE u5vucost
      SET    evo_recalccost = '+', evo_costcalculated = '-'
      WHERE  evo_event = evo.evo_event
      AND    NVL( evo_recalccost, '-' ) <> '+';
    end if;

exception 
  when err then
     RAISE_APPLICATION_ERROR (  -20003,iErrMsg) ;  
  when others then 
     RAISE_APPLICATION_ERROR (  -20003,'Error in Flex r5eventcost/Post Update/10/'||substr(SQLERRM, 1, 500)) ;   
end;