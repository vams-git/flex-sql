declare 
  evt            r5events%rowtype;
  vCurrReading   r5readings.Rea_Reading%type;
  vPPOMeterDue   r5ppmobjects.ppo_meterdue%type;
  vPPOMetUOM     r5ppmobjects.ppo_metuom%type;
  vWODesc        r5events.evt_desc%type;
  vReleaseDate   date; 
  vPpaudfnum02   number;
  vCount         number;  
  iErrMsg        varchar2(400);   
  test_err       exception;  
  
begin
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_status ='25TP' and evt.evt_ppopk is not null and evt.evt_meterdue is not null and trunc(evt.evt_target) = trunc(sysdate) and  evt.evt_parent is null then
     
     select min(ava_changed) into vReleaseDate
     from R5AUDVALUES where ava_primaryid = evt.evt_code and ava_from ='A' and ava_to ='25TP';

     begin
       select rea_reading,1 into vCurrReading,vCount
       --count(1) into vCount
       from   r5readings
       where  rea_object = evt.evt_object and rea_object_org = evt.evt_object_org
       and    abs(rea_created - vReleaseDate) * 24*60*60 <= 10;
    exception when no_data_found then
       vCount := 0;
    end;  
    
     --only trigger when Meter base PM is released
     if vCount > 0 and abs(sysdate - vReleaseDate)* 24*60*60 <= 5 then
        --update wo desc
        if evt.evt_org ='TAS' then
          if instr(evt.evt_desc,'- Due:') = 0 then
           select ppo.ppo_meterdue,ppo.ppo_metuom
           into vPPOMeterDue,vPPOMetUOM
           from r5ppmobjects ppo
           where ppo_pk = evt.evt_ppopk;
           
           vWODesc := SUBSTR(evt.evt_desc || ' - Due: ' || vPPOMeterDue ||' ' ||vPPOMetUOM,1,80);
           
           update r5events e
           set e.evt_desc = vWODesc
           where e.rowid=:rowid
           and e.evt_desc <> vWODesc;
          end if;
        end if; 
        
       --update scheudle end date 
       begin
        select nvl(ppa_udfnum02,1) into vPpaudfnum02
        from   r5ppmacts
        where  ppa_ppm = evt.evt_ppm and ppa_revision = evt.evt_ppmrev
        and    rownum <= 1;
       exception when no_data_found then
        vPpaudfnum02 := 1;
       end;
       
        if vPpaudfnum02 > 1 then 
           --iErrMsg := 'Old Target : ' ||  to_char(evt.evt_target,'DD-MON-YYYY HH:mi:ss') || ' New Target: ' || to_char(evt.evt_target + vPpaudfnum02 - 1,'DD-MON-YYYY HH:mi:ss');
           --raise test_err;
           update r5events e
           set e.evt_target = evt_target + vPpaudfnum02 - 1,
               e.evt_schedend = evt_schedend + vPpaudfnum02 - 1
           where e.rowid=:rowid
           and e.evt_target <> evt_target + vPpaudfnum02 - 1;

        end if;
     end if;
 end if;
/*exception 
  when test_err then 
  RAISE_APPLICATION_ERROR (-20003,iErrMsg);  
 when others then 
   -- RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;        
   RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5EVENTS/Post Update/210');   */
end;
