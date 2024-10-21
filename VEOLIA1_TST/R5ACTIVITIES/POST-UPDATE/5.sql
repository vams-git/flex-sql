DECLARE
    act            r5activities%ROWTYPE;
    vtotalactest   r5activities.act_est%TYPE;
    vfirstact      r5activities.act_act%TYPE;
    vtaskdesc      r5tasks.tsk_desc%TYPE;
  
  vNewValue      r5audvalues.ava_to%type;
    vOldValue      r5audvalues.ava_from%type;
    vTimeDiff      number;
  
    ierrmsg        VARCHAR2(400);
    err_chk        EXCEPTION;
BEGIN
    select * into act from r5activities where rowid =:rowid;
  
    begin
          select ava_to,ava_from,timediff into vNewValue,vOldValue,vTimeDiff
          from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5ACTIVITIES' and aat_column IN ('ACT_TASK','ACT_EST','ACT_UDFNUM01')
          and   ava_table = 'R5ACTIVITIES' 
          and   ava_primaryid = act.act_event and ava_secondaryid = act.act_act
          and   ava_updated = '+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 <= 3
          order by ava_changed desc
          ) where rownum <= 1;
      exception when no_data_found then 
        vNewValue := null;
        return;
      end;

     --select sum(case when act_udfchkbox01 = '+' and evt_jobtype = 'MEC' then nvl(act_udfnum01, 0) else nvl(act_est, 0) end)
     select sum(case when evt_jobtype = 'MEC' then nvl(act_udfnum01, 0) else nvl(act_est, 0) end)
     into   vtotalactest
     from   r5activities,r5events
     where   act_event = evt_code and evt_code = act.act_event;

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
    WHEN err_chk THEN
      Raise_application_error (-20003, ierrmsg);
    WHEN OTHERS THEN
      Raise_application_error (-20003,'Error in Flex R5ACTIVITIES/Post Update/5/'||Substr(SQLERRM, 1, 500));
END; 