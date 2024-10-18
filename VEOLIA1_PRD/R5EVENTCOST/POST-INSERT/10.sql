declare 
  evo   r5eventcost%rowtype;
begin
    select * into evo from r5eventcost where rowid= :rowid;
   /* Add record in r5eventcost. */
    insert into u5vucost
    (evo_event, evo_recalccost, evo_costcalculated,evo_updated,
     createdby,created,updatedby,updated,updatecount)
    VALUES(evo.evo_event, '-', '-' ,sysdate,
    o7sess.cur_user,sysdate,o7sess.cur_user,sysdate,0);

exception
     when others then
     RAISE_APPLICATION_ERROR (  -20003,'Error in Flex r5eventcost/Post Insert/10/'||substr(SQLERRM, 1, 500)) ;   
end;