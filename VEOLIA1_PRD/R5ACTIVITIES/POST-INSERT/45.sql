declare 
     v_chk      varchar2(100);
     v_Count    number;  
     v_Count_two  number;  

     act        r5activities%rowtype;
     evt        r5events%rowtype;
     
     iErrMsg    varchar2(400);
     db_error   exception;
     
     cursor cur_child(vParent varchar2) is 
     select evt_code from r5events where evt_parent =vParent;

begin
    select * into act from r5activities where rowid=:rowid;
    select * into evt from r5events where evt_code = act.act_event;
    select count(1) into v_Count
    from   r5maintenancepatterns mp
    where  mp.mtp_code = evt.evt_mp and mp.mtp_org = evt.evt_mp_org and mp.mtp_revision = evt.evt_mp_rev
    and    mp.mtp_allowduplicatewo = '+';
    select count(1) into v_Count_two
    from r5events ev where ev.evt_parent =evt.evt_code;
    
    if v_Count > 0 and v_Count_two > 0 then
        for rec_child in cur_child(evt.evt_code) loop

            begin
               insert into r5activities
               (act_event,act_act,act_start,act_time,act_hire,act_ordered,act_fixh,act_minhours,
               act_mrc,act_trade,act_persons,act_project,act_projbud,
               act_duration,act_est,act_rem,act_nt,act_ntrate,act_ot,act_otrate,
               act_task,act_taskrev,act_note,act_supplier,act_supplier_org,
               act_special,act_completed,act_qty,act_planninglevel,
               act_udfchar01,
               act_udfchar02,
               act_udfchar03,
               act_udfchar04,
               act_udfchar05,
               act_udfchar06,
               act_udfchar07,
               act_udfchar08,
               act_udfchar09,
               act_udfchar10,
               act_udfchar11,
               act_udfchar12,
               act_udfchar13,
               act_udfchar14,
               act_udfchar15,
               act_udfchar16,
               act_udfchar17,
               act_udfchar18,
               act_udfchar19,
               act_udfchar20,
               act_udfchar21,
               act_udfchar22,
               act_udfchar23,
               act_udfchar24,
               act_udfchar25,
               act_udfchar26,
               act_udfchar27,
               act_udfchar28,
               act_udfchar29,
               act_udfchar30,
               act_udfnum01,
               act_udfnum02,
               act_udfnum03,
               act_udfnum04,
               act_udfnum05,
               act_udfdate01,
               act_udfdate02,
               act_udfdate03,
               act_udfdate04,
               act_udfdate05,
               act_udfchkbox01,
               act_udfchkbox02,
               act_udfchkbox03,
               act_udfchkbox04,
               act_udfchkbox05,
               act_udfnote01,
               act_udfnote02
               )
                select 
                rec_child.evt_code,act_act,act_start,act_time,act_hire,act_ordered,act_fixh,act_minhours,
                act_mrc,act_trade,act_persons,act_project,act_projbud,
                act_duration,0,0,act_nt,act_ntrate,act_ot,act_otrate,
                act_task,act_taskrev,act_note,act_supplier,act_supplier_org,
                act_special,act_completed,0,act_planninglevel,
                act_udfchar01,
                 act_udfchar02,
                 act_udfchar03,
                 act_udfchar04,
                 act_udfchar05,
                 act_udfchar06,
                 act_udfchar07,
                 act_udfchar08,
                 act_udfchar09,
                 act_udfchar10,
                 act_udfchar11,
                 act_udfchar12,
                 act_udfchar13,
                 act_udfchar14,
                 act_udfchar15,
                 act_udfchar16,
                 act_udfchar17,
                 act_udfchar18,
                 act_udfchar19,
                 act_udfchar20,
                 act_udfchar21,
                 act_udfchar22,
                 act_udfchar23,
                 act_udfchar24,
                 act_udfchar25,
                 act_udfchar26,
                 act_udfchar27,
                 act_udfchar28,
                 act_udfchar29,
                 act_udfchar30,
                 act_udfnum01,
                 act_udfnum02,
                 act_udfnum03,
                 act_udfnum04,
                 act_udfnum05,
                 act_udfdate01,
                 act_udfdate02,
                 act_udfdate03,
                 act_udfdate04,
                 act_udfdate05,
                 act_udfchkbox01,
                 act_udfchkbox02,
                 act_udfchkbox03,
                 act_udfchkbox04,
                 act_udfchkbox05,
                 act_udfnote01,
                 act_udfnote02
                 from r5activities a
                 where rowid =:rowid;
            exception when others then
              null;
            end; 
          
        end loop;
    end if;

exception 
WHEN db_error then
   RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
WHEN others THEN 
   RAISE_APPLICATION_ERROR ( -20003,'Error in Flex/R5EVENTS/16/Insert'||substr(SQLERRM, 1, 500));
end;
