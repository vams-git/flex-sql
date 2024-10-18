--Only centain user group could cancel Statutory WO 
DECLARE
    icount        number;
    rec_event     r5events%rowtype;
    DB_ERROR1     exception;
    iLang         r5users.usr_lang%type;
    iErrMsg       varchar2(500);
    vCloComment   number;
    vOrgUdfchar10 r5organization.org_udfchar10%type;
    vUsrGroup     r5users.Usr_Group%type;
BEGIN
   select * into rec_event from r5events where rowid=:rowid; 
   if (rec_event.evt_type not in ('JOB','PPM')) then return; end if;
   if rec_event.evt_jobtype = 'MEC' then return; end if;

   if rec_event.evt_status = '30CL' and rec_event.evt_udfchkbox05='+' then
     --get current user group
     /*
     select usr.usr_group into vUsrGroup
     from r5users usr
     where  usr_code = o7sess.cur_user;
     */
     select usr.uog_group into vUsrGroup
     from r5userorganization usr
     where  usr.uog_user = o7sess.cur_user
      and usr.uog_org = rec_event.evt_org
      and usr.uog_role = o7sess.cur_role;
     
     
     --only listed user group could cancel statuory WO
     if vUsrGroup not in 
          ('R5', 
          'ADMIN',
          'VWA-ADMIN',
          'VWA-ADMIN-S',
          'VNZ-CMAN',
          'VNZ-ADMIN-S',
          'QGC-AMT',
          'VAU-ADMIN-S',
          'VCS-ADMIN',
          'VCS-ADMIN-S',
          'VCS-CMAN',
          'VCS-MS',
          'VCS-AMT'
          ) then
            iErrMsg := 'You are not authorize to cancel statuory WO, please contact Admin.';
            raise db_error1;
      else 
        --All statutory WO must have a comment (in comment tab or closing comment tab) in order to be cancelled
        select count(1) into vCloComment from r5addetails
        where add_code = rec_event.evt_code and add_rentity ='EVNT';
        if vCloComment = 0 then
            iErrMsg := 'Please enter comment before cancel statuory WO.';
            raise db_error1;
         end if;
      end if;
     end if; -- rec_event.evt_status = '30CL' and rec_event.evt_udfchkbox05='+'
     
     --The statutory WO must also have a cancellation reason (UDF 21).
     if rec_event.evt_status = '30CL' then
        select org_udfchar10 into vOrgUdfchar10
        from r5organization where org_code = rec_event.evt_org;
        if vOrgUdfchar10 like '%Fleet%' and rec_event.evt_udfchar21 is null then 
           iErrMsg := '(Fleet) Please confirm a reason for cancellation in the matching field.';
           raise db_error1;
        end if;
     end if; --rec_event.evt_status = '30CL' 



   

exception 
  when DB_ERROR1 then
    RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then
    RAISE_APPLICATION_ERROR ( -20003,'Error in Flex R5EVENTS/Post Update/300/'||substr(SQLERRM, 1, 500)) ; 
END;
