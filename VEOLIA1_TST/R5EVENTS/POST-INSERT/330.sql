DECLARE
    rec_event     r5events%rowtype;
    vUser         r5users.usr_code%type;
    vCount        number;
    vPerSite      number;
    v_obj_status  r5objects.obj_status%type;
    err           exception;
    iErrMsg       nvarchar2(400);
BEGIN
   select * into rec_event from r5events where rowid=:rowid; 
   if (rec_event.evt_type not in ('JOB')) then return; end if;
   
   vUser := o7sess.cur_user;
   select count(1) into vCount from r5users  
   where usr_code = vUser
   and   usr_udfchkbox01='+';
   if vCount > 0 then
      select count(1) into vPerSite from U5SITEPERMISSION
      where  SIP_USER =  vUser
      and    SIP_SITE =  rec_event.evt_object and SIP_SITEORG = rec_event.evt_object_org;
      
      select count(1) into vCount from (
      select stc_child,stc_child_org from r5structures
      connect by prior stc_child = stc_parent
      start with stc_parent||stc_parent_org
      in (select SIP_SITE||SIP_SITEORG from U5SITEPERMISSION 
      WHERE SIP_USER =vUser)
      )
      where  stc_child = rec_event.evt_object and stc_child_org = rec_event.evt_object_org;
      
      if  vPerSite = 0 and vCount = 0 then
          iErrMsg := 'You do not have permission to create WO for this site.';  
          raise err;
      end if;
   end if;
   
   select obj_status 
   into   v_obj_status
   from   r5objects
   where  obj_code = rec_event.evt_object and obj_org = rec_event.evt_object_org;
   if v_obj_status in ('O') then 
     iErrMsg := 'You can not create WO with Unfinished Equipment.';  
     raise err;
   end if;
   
   if rec_event.evt_jobtype ='MEC' then
      update u5vucost set evo_recalcesthr ='+',evo_esthrcalculated='-' where evo_event = rec_event.evt_code;
   end if;
   
exception 
  when err then
       RAISE_APPLICATION_ERROR ( -20003,'ERR/R5EVENTS/330/I - '||iErrMsg) ; 
END;
