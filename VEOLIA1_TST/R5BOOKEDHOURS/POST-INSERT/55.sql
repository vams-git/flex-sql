declare 
   boo r5bookedhours%rowtype;
   vOrg r5events.evt_org%type;
   vHours r5bookedhours.boo_hours%type;
  
   DB_ERROR exception;
   iErrMsg  varchar2(400);
begin
   select * into boo from r5bookedhours where rowid =:rowid;
   select evt_org into vOrg from r5events where evt_code = boo.boo_event;
   
   if vOrg in ('WAU','NWA','WAR','SAU') and boo.boo_person is not null then
     if boo.boo_octype = 'C'  then
        select sum(nvl(boo_hours,boo_orighours)) into vHours
        from r5bookedhours b2 
        where b2.boo_person = boo.boo_person
        and b2.boo_date = boo.boo_date
        and b2.boo_octype = boo.boo_octype;
        
        if (boo.boo_correction = '-' and  abs(vHours) <> 4) 
          or (boo.boo_correction = '+' and  abs(vHours) <> 0) then
           iErrMsg := 'Please only enter 4 hours for Call-Out type.';
           raise DB_ERROR;
        end if;
     end if;
     
     if boo.boo_octype not in ('N','O','C') then
        iErrMsg := 'You can only enter N,O or C Type of Hours.';
        raise DB_ERROR;
     end if;
   end if;
   
   if vOrg in ('NVE','NVP','NVW') and boo.boo_person is not null then
     if boo.boo_octype = 'C'  and abs(nvl(boo.boo_hours,boo.boo_orighours)) < 2 then
        iErrMsg := 'Please enter minimum 2 hour for Call-Out type.';
        raise DB_ERROR;
     end if;
     
     if boo.boo_octype not in ('N','C') then
        iErrMsg := 'You can only enter N or C Type of Hours.';
        raise DB_ERROR;
     end if;
   end if;

   if vOrg in ('NSW') and boo.boo_person is not null then
     if boo.boo_octype = 'C'  and abs(nvl(boo.boo_hours,boo.boo_orighours)) != 1 then
        iErrMsg := 'Please only enter 1 hour for Call-Out type.';
        raise DB_ERROR;
     end if;
     
     if boo.boo_octype not in ('N','NH','O','C') then
        iErrMsg := 'You can only enter N,NH,O or C Type of Hours.';
        raise DB_ERROR;
     end if;
   end if;

   if vOrg in ('TAS') and boo.boo_person is not null then
     if boo.boo_octype = 'C'  and abs(nvl(boo.boo_hours,boo.boo_orighours)) != 1 then
        iErrMsg := 'Please only enter 1 hour for Call-Out type.';
        raise DB_ERROR;
     end if;
     
     if boo.boo_octype not in ('N','O','C') then
        iErrMsg := 'You can only enter N,O or C Type of Hours.';
        raise DB_ERROR;
     end if;
   end if;
     
   if vOrg in ('QLD','NTE','VIC') and boo.boo_person is not null then
     if boo.boo_octype not in ('N','O') then
        iErrMsg := 'You can only enter N, or O Type of Hours.';
        raise DB_ERROR;
     end if;
   end if;

 --end if; 
exception 
  WHEN DB_ERROR THEN
     RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5BOOKEDHOURS/55/I - ' ||iErrMsg) ; 
  when others then
     RAISE_APPLICATION_ERROR ( -20003, 'ERR/R5BOOKEDHOURS/55/I - ' ||SQLCODE || SQLERRM) ; 
end;