DECLARE
    act            r5activities%ROWTYPE;
    vtotalactest   r5activities.act_est%TYPE;
    vfirstact      r5activities.act_act%TYPE;
    vtaskdesc      r5tasks.tsk_desc%TYPE;
    
    iErrMsg        varchar2(400);
    err            exception;
BEGIN
    select * into act from r5activities where rowid =:rowid;
    
    select sum(case when evt_jobtype = 'MEC' then Nvl(act_udfnum01, 0) else Nvl(act_est, 0) end)  
    --select SUM(CASE WHEN act_udfchkbox01 = '+' AND evt_jobtype = 'MEC' THEN Nvl(act_udfnum01, 0) ELSE Nvl(act_est, 0) END)      
    into   vtotalactest
    from   r5activities, r5events     
    where  act_event = evt_code and evt_code = act.act_event;
    
    -- iErrMsg := vtotalactest;
     --raise err;
          

    BEGIN
        SELECT Min(act_act)
        INTO   vfirstact
        FROM   r5activities
        WHERE  act_event = act.act_event
               AND act_task IS NOT NULL;

        SELECT tsk_desc
        INTO   vtaskdesc
        FROM   r5activities,
               r5tasks tsk
        WHERE  act_event = act.act_event
               AND act_task = tsk_code
               AND act_taskrev = tsk_revision
               AND act_act = vfirstact;
    EXCEPTION
        WHEN no_data_found THEN
          vtaskdesc := NULL;
    END;

    UPDATE r5events
    SET    evt_udfnum04 = vtotalactest,
           evt_udfchar25 = vtaskdesc
    WHERE  evt_code = act.act_event
           AND ( Nvl(evt_udfnum04, 0) <> Nvl(vtotalactest, 0)
                  OR Nvl(evt_udfchar25, ' ') <> Nvl(vtaskdesc, ' ') );
EXCEPTION
   
    WHEN err THEN
      Raise_application_error (-20003,iErrMsg);
     WHEN OTHERS THEN
      Raise_application_error (-20003,'Error in Flex R5ACTIVITIES/Post Insert/5/'||Substr(SQLERRM, 1, 500));
END; 