declare 
  obj               r5objects%rowtype;
  evt               r5events%rowtype; 
  boo               r5bookedhours%rowtype;
  
  vSpiltTimeStamp   varchar2(80);
  vLastBookOff      varchar2(30);
  vLastBookEvent    r5events.evt_code%type;
  vLastBookCode     r5bookedhours.boo_code%type;
  vLastBookAct      r5bookedhours.boo_act%type;
  vNextBookOn       varchar2(30);
  vNextBookEvent    r5events.evt_code%type;
  vNextBookAct      r5bookedhours.boo_act%type;
  vNextBooCode      r5bookedhours.boo_code%type;
  vCurrBooOn        varchar2(30);
  vCurrBooOff       varchar2(30);
  vGap              number;
  vRevertBooCode    r5bookedhours.boo_code%type;
  vBurMrcCnt        number;
  vThisShiftStartTime date;
  vThisShiftStartCode varchar2(30);
  vConsecDiff         number;
  
  vDay              varchar2(5);
  vPerType          varchar2(30);
  vSumRuleSec       number;
  vBooHours         r5bookedhours.boo_hours%type;
  vBooOrigHours     r5bookedhours.boo_orighours%type;
  
  vNewPoint         r5bookedhours.boo_on%type;
  vEndPoint         r5bookedhours.boo_on%type;
  vNewPointDateTime varchar2(30);
  
  vExistHours       r5bookedhours.boo_hours%type;
  vToBeBookedHours  r5bookedhours.boo_hours%type;
  vSumBookedHours   r5bookedhours.boo_hours%type;
  
  vBooOn            r5bookedhours.boo_on%type;
  vBooOff           r5bookedhours.boo_off%type;
  vOctType          r5bookedhours.boo_ocrtype%type;
  vPriHours         r5bookedhours.boo_hours%type;
  
  vBooOn_1          r5bookedhours.boo_on%type;
  vBooOff_1         r5bookedhours.boo_off%type;
  vOctType_1        r5bookedhours.boo_ocrtype%type;
  vEsc1Hours        r5bookedhours.boo_hours%type;
  
  vBooOn_2          r5bookedhours.boo_on%type;
  vBooOff_2         r5bookedhours.boo_off%type;
  vOctType_2        r5bookedhours.boo_ocrtype%type;
  vEsc2Hours        r5bookedhours.boo_hours%type;
 
  oTrrStartDate     date;
  oTrrEndDate       date;
  oTrrRate          r5bookedhours.boo_rate%type;
  chk               varchar2(5);
  
  vCount            number;
  iErrMsg           varchar2(4000);
  err_val           exception;
  
  
 
  cursor cur_boo(vParent varchar2,vParentOrg varchar2) is 
  select evt_code,boo_act,boo_person,boo_orighours,boo_hours,
  boo_date,boo_on,boo_off,boo_octype,boo_udfchar02,boo_code
  from r5events,r5bookedhours,
  (select
  stc_child_org,stc_child,stc_childtype,stc_childrtype,
  stc_parent,level
  ,ltrim(sys_connect_by_path(stc_child ,'/'),'/') path
  from
  r5structures
  connect by prior stc_child = stc_parent and prior stc_child_org = stc_parent_org
  start with stc_parent = vParent and stc_parent_org = vParentOrg
  union 
  select obj_org,obj_code,null,null,null,0,obj_code 
  from r5objects where obj_code = vParent and obj_org = vParentOrg
  ) stc_obj
  where evt_code = boo_event
  and   evt_object = stc_obj.stc_child and evt_object_org = stc_obj.stc_child_org
  and   evt_type in ('JOB','PPM')
  and   evt_org = vParentOrg
  and   evt_jobtype in ('MC') and evt_parent is null
  and   boo_person is not null and nvl(boo_orighours,boo_hours) > 0 
  and   boo_date is not null and boo_on is not null and boo_off is not null
  and   boo_octype in ('OD') and boo_udfchar02 is null --and boo_udfchar02 LIKE 'Err%' 
  and   (
        (evt_org in ('ALC') and evt_class not in ('OP') and evt_status in ('46MS','49MF','50SO','51SO','55CA'))
     or (evt_org in ('BPK','SYN') and evt_class not in ('OP') and evt_status in ('46MS','49MF','50SO','51SO','55CA'))
     or (evt_org in ('PKM') and evt_class not in ('OP') and evt_status in ('50SO','51SO','55CA'))
     or (evt_org not in ('ALC','BPK','PKM') and evt_class not in ('OP') and evt_status in ('49MF','50SO','51SO','55CA'))
     or (evt_class in ('OP') and evt_rstatus not in ('A','C'))
  )
  AND   to_date(
        to_char(boo_date,'YYYY-MM-DD') ||' '||
        to_char(trunc(boo_on/3600), 'FM9999999900')|| decode(boo_on,null,null, ':')|| to_char(trunc(mod(boo_on,3600)/60), 'FM00')
        ,'YYYY-MM-DD HH24:MI') < to_date(to_char(sysdate,'YYYY-MM-DD')|| ' 06:00','YYYY-MM-DD HH24:MI')
  order by boo_person,boo_date,boo_on;
  
  --cursor cur_bur(inOrg varchar2,inDay varchar2,inWorkDateStr in varchar2,inBooStartDate date,inBooEndDate date) is
  cursor cur_bur(inOrg varchar2,inDay varchar2,inPerType varchar2,inBooMrc varchar2) is
  select *
  from u5burule u1
  where bur_org = inOrg 
  and   bur_day = inDay 
  and   bur_pertype = inPerType
  and 
  (
  (bur_mrc = inBooMrc
  and (select count(1) from  u5burule u2 
  where u1.bur_org = u2.bur_org and u1.bur_day = u2.bur_day and u1.bur_pertype = u2.bur_pertype and u2.bur_mrc = inBooMrc)> 0)
   or (bur_mrc is null and (select count(1) from  u5burule u2 
   where u1.bur_org = u2.bur_org and u1.bur_day = u2.bur_day and u1.bur_pertype = u2.bur_pertype and u2.bur_mrc = inBooMrc)=0)
  )
  --and   to_date(inWorkDateStr||' '||bur_starthour,'YYYY-MM-DD HH24:MI') <= inBooStartDate
  --and   to_date(inWorkDateStr||' '||bur_endhour,'YYYY-MM-DD HH24:MI')   >= inBooEndDate
  order by bur_org,bur_day,bur_starthour;
  
  cursor cur_consechrs(vPerson varchar2,vCurrBooCode varchar2,vBooDateOn date) is
  select 
  boo_event,boo_person,boo_date,boo_octype,boo_on,boo_off,boo_hours,boo_startdate,boo_enddate,
  LAG(boo_startdate,1) OVER (ORDER BY boo_person,boo_enddate desc) as boo_prev_startdate,
  abs(nvl(to_number(boo_enddate  - LAG(boo_startdate,1) OVER (ORDER BY boo_person,boo_enddate desc )) * 24,0)) as boo_diff,
  boo_code,LAG(boo_code,1) OVER (ORDER BY boo_person,boo_enddate desc) as boo_prev_code,
  boo_udfchar04,boo_udfchkbox01,boo_udfchkbox02
  from 
  (
  select 
  boo_event,boo_person,boo_date,boo_octype,boo_on,boo_off,boo_hours,
  to_date(to_char(boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo_on/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo_on,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') AS boo_startdate,
  case when boo_off = 86400 THEN BOO_DATE + 1  else
  to_date(to_char(boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo_off/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo_off,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') 
  end as boo_enddate,
  ROW_NUMBER() OVER (PARTITION by boo_person order by  boo_date,boo_on desc) AS PER_RANK,boo_code,boo_udfchar04,boo_udfchkbox01,boo_udfchkbox02
  from r5bookedhours 
  where boo_person =vPerson
  and boo_date > trunc(vBooDateOn) - 15
  and boo_date < vBooDateOn
  --and boo_code <= vCurrBooCode
  and boo_octype not in ('OD')
  and nvl(boo_orighours,boo_hours)>0 and boo_on is not null 
  --and boo_udfchkbox02 not in ('+') and nvl(boo_udfchar02,' ') not LIKE 'Err%' 
  order by boo_date desc ,boo_on desc
  );
  
 
  
begin  
  select * into obj from r5objects where rowid=:rowid;
  if obj.obj_udfchar22 is not null and obj.obj_udfchar22 like 'FUNSPILT%' and obj.obj_status in ('VAL') and obj.obj_obrtype in ('P') then
  vSpiltTimeStamp := replace(obj.obj_udfchar22,'FUNSPILT-');

  for rec_boo in cur_boo(obj.obj_code,obj.obj_org) loop
     begin
       select * into boo from r5bookedhours where boo_code = rec_boo.boo_code;
       select * into evt from r5events where evt_code = rec_boo.evt_code;
       --Get CurrBooOn and CurrBooOff (String) 
       dbms_output.put_line('---------');
       select
       to_char(boo.boo_date,'YYYY-MM-DD') ||' '||
       to_char(trunc(boo.boo_on/3600), 'FM9999999900')|| decode(boo.boo_on,null,null, ':')|| to_char(trunc(mod(boo.boo_on,3600)/60), 'FM00')
       into vCurrBooOn from dual; 
       select
       case when boo.boo_off/3600 = 24 then to_char(boo.boo_date + 1,'YYYY-MM-DD') ||' 00:00'
       else
       to_char(boo.boo_date,'YYYY-MM-DD') ||' '||
       to_char(trunc(boo.boo_off/3600), 'FM9999999900')|| decode(boo.boo_off,null,null, ':')|| to_char(trunc(mod(boo.boo_off,3600)/60), 'FM00')
       end
       into vCurrBooOff from dual;
       
      
       --Validate 1 --Check Interval between current start time and Last End Time. It must be <0.5 or > 10 (vGap < 10 and vGap > 0.5)
       begin
          select boo_event,boo_act,boo_dateoff,boo_code
          into vLastBookEvent,vLastBookAct,vLastBookOff,vLastBookCode from (
          select boo_event,boo_act,boo_dateoff,boo_code from (
          select
          boo_event,boo_act,boo_code, 
          case when boo_off/3600 = 24 then to_char(boo_date + 1,'YYYY-MM-DD') ||' 00:00'
          else
          to_char(boo_date,'YYYY-MM-DD') ||' ' ||
          to_char(trunc(boo_off/3600), 'FM9999999900')|| decode(boo_off,null,null, ':')|| to_char(trunc(mod(boo_off,3600)/60), 'FM00')
          end as boo_dateoff
          from r5bookedhours
          where boo_person = boo.boo_person 
          and   to_date(to_char(boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo_on/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo_on,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI')
          < to_date(vCurrBooOn,'YYYY-MM-DD HH24:MI')
          and boo_octype not in ('OD') and nvl(boo_orighours,boo_hours) > 0  
          and boo_on is not null
          )
          order by boo_dateoff desc
          ) where rownum <= 1;
        exception when no_data_found then
           vLastBookOff:= '1900-01-01 00:00';
        end;    
        if vLastBookOff <> '1900-01-01 00:00' then
           vGap := ROUND((to_date(vCurrBooOn,'YYYY-MM-DD HH24:MI') - to_date(vLastBookOff,'YYYY-MM-DD HH24:MI')) * 24,1);
           if vGap < 10 and vGap > 0.5 then 
             --return;
             update r5bookedhours 
             set boo_udfchar02 = substr('Err:LastvBoo-'||
            ' BooCode:'||vLastBookCode||
            ' WO:'||vLastBookEvent||'/'||vLastBookAct||
            ' LastEnd:'||vLastBookOff||
            ' Gap:' || vGap,1,80),
             boo_udfchar04 = vSpiltTimeStamp
             where boo_code = boo.boo_code;
             continue;  
            end if;
        end if;
        
        --Validate 2 --Check Interval Between current end time and next start time. It must be more than <0.5 or > 10
        begin
          select
          boo_event,boo_act,boo_dateon,boo_code
          into vNextBookEvent,vNextBookAct, vNextBookOn,vNextBooCode
          from (
          select boo_event,boo_code,boo_act,boo_dateon from (
          select
          boo_event,boo_act,boo_code, 
          case when boo_on/3600 = 24 then to_char(boo_date + 1,'YYYY-MM-DD') ||' 00:00'
          else
          to_char(boo_date,'YYYY-MM-DD') ||' ' ||
          to_char(trunc(boo_on/3600), 'FM9999999900')|| decode(boo_on,null,null, ':')|| to_char(trunc(mod(boo_on,3600)/60), 'FM00')
          end as boo_dateon
          from r5bookedhours
          where boo_person = boo.boo_person 
          and   to_date(to_char(boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo_on/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo_on,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI')
          > to_date(vCurrBooOn,'YYYY-MM-DD HH24:MI')
          and boo_octype not in ('OD') and nvl(boo_orighours,boo_hours) > 0  
          and boo_off is not null
          )
          order by boo_dateon asc
          ) where rownum <= 1;
         exception when no_data_found then
           vNextBookOn:= '1900-01-01 00:00';
         end; 
         if vNextBookOn <> '1900-01-01 00:00' then
            vGap := abs(ROUND((to_date(vNextBookOn,'YYYY-MM-DD HH24:MI') - to_date(vCurrBooOff,'YYYY-MM-DD HH24:MI')) * 24,1));
            if vGap < 10 and vGap > 0.5 then 
               --return;
               update r5bookedhours 
               set boo_udfchar02 = substr('Err:NextBoo-'||
              ' BooCode:'||vNextBooCode||
              ' WO:'||vNextBookEvent||'/'||vNextBookAct||
              ' NextStart:'||vNextBookOn||
              --' CurrentStartTime-'||vCurrBooOn||
              ' Gap:' || vGap,1,80),
               boo_udfchar04 = vSpiltTimeStamp
               where boo_code = boo.boo_code;
               continue;  
            end if;
         end if; 
     
       --Get Day to retrieve Bookrules by Day
       select case
       when to_char(boo.boo_date,'D') = '1' then 'SUN'
       when to_char(boo.boo_date,'D') = '2' then 'MON'
       when to_char(boo.boo_date,'D') = '3' then 'TUE'
       when to_char(boo.boo_date,'D') = '4' then 'WED'
       when to_char(boo.boo_date,'D') = '5' then 'THU'
       when to_char(boo.boo_date,'D') = '6' then 'FRI'
       when to_char(boo.boo_date,'D') = '7' then 'SAT'
       end into vDay from dual;

              
       if vDay not in ('SAT','SUN') then
          select count(1) into vCount from U5CCTRCALDAYS 
          where cgd_grouporg = evt.evt_org and trunc(cgd_date) = trunc(boo.boo_date) and nvl(cgd_isnonwork,'-') = '+';
          if vCount > 0 then
             vDay := 'PH';
          end if;
       end if;
           
                      
       --Add on 08-AUG-2019 Get PER Type to retrieve Bookrules By Day and Per Type
       select per_udfchar03 into vPerType
       from   r5personnel 
       where per_code = boo.boo_person;
           
       --Validate Rules is completed configurtion?
       --get Configure ByDpart cnt
       select count(1) into vBurMrcCnt 
       from u5burule
       where bur_org = evt.evt_org 
       and   bur_day = vDay
       and   bur_pertype = vPerType
       and   bur_mrc = boo.boo_mrc;
       if vBurMrcCnt > 0 then
         select sum(bur_off - bur_on) into vSumRuleSec
         from u5burule 
         where bur_org = evt.evt_org 
         and   bur_day = vDay
         and   bur_pertype = vPerType
         and   boo.boo_mrc = bur_mrc;
         if nvl(vSumRuleSec,0) <> 86400 then
            iErrMsg := 'Err: Labor Hours Rules for Empolyee Type '||vPerType || ' On ' || vDay || ' For ' || boo.boo_mrc || ' configuration is not completed, plese contact Administrator!';
            raise err_val;
         end if;
       else
         select sum(bur_off - bur_on) into vSumRuleSec
         from u5burule 
         where bur_org = evt.evt_org 
         and   bur_day = vDay
         and   bur_pertype = vPerType
         and   bur_mrc is null;
         if nvl(vSumRuleSec,0) <> 86400 then
            iErrMsg := 'Err: Labor Hours Rules for Empolyee Type '||vPerType || ' On ' || vDay || ' configuration is not completed, plese contact Administrator!';
            raise err_val;
         end if;
       end if;  

       --Insert Revert for OD type before spilt works
       if boo.boo_hours is not null then
          vBooHours := boo.boo_hours * -1;
       end if;
       if boo.boo_orighours is not null then
          vBooOrigHours := boo.boo_orighours * -1;
       end if;         
       insert into r5bookedhours
       (boo_event,boo_act,boo_trade,boo_person,boo_mrc,boo_desc,boo_routeparent,
        boo_udfchar01,boo_udfchar02,boo_udfchar04,boo_date,
        boo_octype,boo_hours,boo_orighours,boo_rate,boo_correction,boo_udfchkbox01,
        boo_on,boo_off,boo_correction_ref)
       values
       (boo.boo_event,boo.boo_act,boo.boo_trade,boo.boo_person,boo.boo_mrc,boo.boo_desc,boo.boo_routeparent,
        boo.boo_udfchar01,boo.boo_code,vSpiltTimeStamp,boo.boo_date,
        boo.boo_octype,vBooHours,vBooOrigHours,boo.boo_rate,'+','+',
        boo.boo_on,boo.boo_off,boo.boo_code)
        returning boo_code into vRevertBooCode;
        --record udfchar02 means it process spilt
        update r5bookedhours 
        set boo_udfchar02 = vRevertBooCode,
        boo_udfchar04 = vSpiltTimeStamp,
        boo_correction_ref = vRevertBooCode
        where boo_code = boo.boo_code;
            
        --Initial New point as user entered value
        vNewPoint := boo.boo_on;
        for rec_bur in cur_bur(evt.evt_org,vDay,vPerType,boo.boo_mrc) loop
            --If intial start time is more than rule end time, skip
            if  boo.boo_on > rec_bur.bur_off then
                CONTINUE; 
            end if;
            --reset value
            vBooOn := 0;
            vBooOff := 0;
            vPriHours := 0;
            vBooOn_1 := 0;
            vBooOff_1 := 0;
            vEsc1Hours := 0;
            vBooOn_2 := 0;
            vBooOff_2 := 0;
            vEsc2Hours := 0;
                
            --new start point (fist record will be start date) is within rules
           if vNewPoint >= rec_bur.bur_on and vNewPoint <= rec_bur.bur_off then --If  3
              --set end pint
              if rec_bur.bur_off < boo.boo_off then
                 vEndPoint := rec_bur.bur_off;
              else
                 vEndPoint := boo.boo_off;
              end if; 
              vExistHours := 0;
              select
              to_char(boo.boo_date,'YYYY-MM-DD') ||' '||
              to_char(trunc(vNewPoint/3600), 'FM9999999900')|| decode(vNewPoint,null,null, ':')|| to_char(trunc(mod(vNewPoint,3600)/60), 'FM00')
              into vNewPointDateTime from dual; 
              for rec_consechrs in cur_consechrs(boo.boo_person,boo.boo_code,to_date(vNewPointDateTime,'YYYY-MM-DD HH24:MI')) loop
                 vConsecDiff := (to_date(vCurrBooOn,'YYYY-MM-DD HH24:MI') - rec_consechrs.boo_enddate) * 24;
                 
                 if vConsecDiff > 0.5 and vConsecDiff >= 10 then
                    vThisShiftStartTime := rec_consechrs.boo_prev_startdate;
                    vThisShiftStartCode := rec_consechrs.boo_prev_code;
                    exit;
                 end if;
                 vExistHours:= vExistHours + rec_consechrs.boo_hours;
             end loop;
             if vThisShiftStartCode is null then
                vThisShiftStartTime := to_date(vCurrBooOn,'YYYY-MM-DD HH24:MI');
                vThisShiftStartCode := boo.boo_code;
             end if;
             dbms_output.put_line('vThisShiftStartTime: ' || to_char(vThisShiftStartTime,'YYYY-MM-DD HH24:MI'));

              vToBeBookedHours := (vEndPoint - vNewPoint)/3600;
              vSumBookedHours := vExistHours + vToBeBookedHours;
              dbms_output.put_line('vSumBookedHours: ' || vSumBookedHours);
                  
              --Senairo 1 : No Escalation type and hours
              --if rec_bur.bur_octype1sum is null or rec_bur.bur_octype1 is null then
                 vOctType := rec_bur.bur_octype;
                 vBooOn := vNewPoint;
                 vBooOff := vEndPoint;
                 vPriHours := vToBeBookedHours;
              --end if;
                  
              --Senairo 2 : Only 1 Level Escalation
              if (rec_bur.bur_octype1sum is not null and rec_bur.bur_octype1 is not null)
                and (rec_bur.bur_octype2sum is null or rec_bur.bur_octype2 is null) then
                if  vSumBookedHours > rec_bur.bur_octype1sum  then
                    vPriHours := nvl(rec_bur.bur_octype1sum - vExistHours,0);
                    if vPriHours <= 0 then 
                      vPriHours := 0; 
                      vBooOn := vNewPoint;
                      vBooOff := vNewPoint + vPriHours * 3600;
                    else
                       vOctType := rec_bur.bur_octype;
                       vBooOn := vNewPoint;
                       vBooOff := vNewPoint + vPriHours * 3600;
                    end if;
                        
                    vEsc1Hours := nvl(vToBeBookedHours - vPriHours,0);
                    if vEsc1Hours <= 0 then 
                      vEsc1Hours := 0;
                      vBooOn_1 := vBooOff;
                      vBooOff_1 := vEndPoint;
                    else
                       vOctType_1 := rec_bur.bur_octype1;
                       vBooOn_1 := vBooOff;
                       vBooOff_1 := vEndPoint;
                    end if;
                 end if;    
              end if;
                  
              --Scenairo 3 :  2 Level Escalation 
              if (rec_bur.bur_octype1sum is not null and rec_bur.bur_octype1 is not null)
                and (rec_bur.bur_octype2sum is not null and rec_bur.bur_octype2 is not null) then
                --Scenairo 3.1 : Total book hours less than esc2 hours
                if (vSumBookedHours > rec_bur.bur_octype1sum) 
                  and (vSumBookedHours <= rec_bur.bur_octype2sum) then --(same as Scenairo 2)
                    vPriHours := nvl(rec_bur.bur_octype1sum - vExistHours,0);
                    if vPriHours <= 0 then 
                      vPriHours := 0; 
                      vBooOn := vNewPoint;
                      vBooOff := vNewPoint + vPriHours * 3600;
                    else
                       vOctType := rec_bur.bur_octype;
                       vBooOn := vNewPoint;
                       vBooOff := vNewPoint + vPriHours * 3600;
                    end if;
                        
                    vEsc1Hours := nvl(vToBeBookedHours - vPriHours,0);
                    if vEsc1Hours <= 0 then 
                      vEsc1Hours := 0;
                      vBooOn_1 := vBooOff;
                      vBooOff_1 := vEndPoint;
                    else
                       vOctType_1 := rec_bur.bur_octype1;
                       vBooOn_1 := vBooOff;
                       vBooOff_1 := vEndPoint;
                    end if;
                end if; --End Scenairo 3.1 
                --Scenairo 3.2 : Total book hours more than esc2 hours
                if (vSumBookedHours > rec_bur.bur_octype2sum) then
                    vPriHours := nvl(rec_bur.bur_octype1sum - vExistHours,0);
                    if vPriHours <= 0 then 
                      vPriHours := 0; 
                      vBooOn := vNewPoint;
                       vBooOff := vNewPoint + vPriHours * 3600;
                    else
                       vOctType := rec_bur.bur_octype;
                       vBooOn := vNewPoint;
                       vBooOff := vNewPoint + vPriHours * 3600;
                    end if;
                        
                    vEsc1Hours := nvl(rec_bur.bur_octype2sum  - vExistHours - vPriHours,0);
                    if vEsc1Hours <= 0 then
                       vEsc1Hours := 0;
                       vBooOn_1 := vBooOff;
                       vBooOff_1 := vBooOff + vEsc1Hours  * 3600;
                    else
                       vOctType_1 := rec_bur.bur_octype1;
                       vBooOn_1 := vBooOff;
                       vBooOff_1 := vBooOff + vEsc1Hours  * 3600;
                    end if;
                        
                    vEsc2Hours := nvl(vToBeBookedHours - vPriHours - vEsc1Hours,0);
                    if vEsc2Hours <= 0 then
                       vEsc2Hours := 0;
                       vBooOn_2 := vBooOff_1;
                       vBooOff_2 := vEndPoint;
                    else
                       vOctType_2 := rec_bur.bur_octype2;
                       vBooOn_2 := vBooOff_1;
                       vBooOff_2 := vEndPoint;
                    end if; 
                 end if;--End Scenairo 3.2
              end if;--End Scenairo 3
  
              if vPriHours > 0 then
                 dbms_output.put_line('vOctType: ' || vOctType ||  '-' || vPriHours);
                 o7boodaterate(boo.boo_person,boo.boo_event,boo.boo_mrc,boo.boo_trade,vOctType,
                 boo.boo_date,oTrrStartDate,oTrrEndDate,oTrrRate,chk);
                 insert into r5bookedhours
                (boo_event,boo_act,boo_trade,boo_person,boo_mrc,boo_desc,boo_routeparent,
                 boo_udfchar01,boo_udfchar02,boo_udfchar04,boo_date,
                 boo_octype,boo_on,boo_off,boo_rate,boo_udfchkbox01)
                values
                (boo.boo_event,boo.boo_act,boo.boo_trade,boo.boo_person,boo.boo_mrc,boo.boo_desc,boo.boo_routeparent,
                 boo.boo_udfchar01,boo.boo_code,vSpiltTimeStamp,boo.boo_date,
                 vOctType,vBooOn,vBooOff,oTrrRate,'+');
              end if;
              if vEsc1Hours > 0 then
                  dbms_output.put_line('vOctType_1: ' || vOctType_1 || '-' || vEsc1Hours);
                 o7boodaterate(boo.boo_person,boo.boo_event,boo.boo_mrc,boo.boo_trade,vOctType_1,
                 boo.boo_date,oTrrStartDate,oTrrEndDate,oTrrRate,chk);
                 insert into r5bookedhours
                (boo_event,boo_act,boo_trade,boo_person,boo_mrc,boo_desc,boo_routeparent,
                 boo_udfchar01,boo_udfchar02,boo_udfchar04,boo_date,
                 boo_octype,boo_on,boo_off,boo_rate,boo_udfchkbox01)
                values
                (boo.boo_event,boo.boo_act,boo.boo_trade,boo.boo_person,boo.boo_mrc,boo.boo_desc,boo.boo_routeparent,
                 boo.boo_udfchar01,boo.boo_code,vSpiltTimeStamp,boo.boo_date,
                 vOctType_1,vBooOn_1,vBooOff_1,oTrrRate,'+');
              end if;
              if  vEsc2Hours > 0 then
                dbms_output.put_line('vOctType_2: ' || vOctType_2||  '-' || vEsc2Hours);
                 o7boodaterate(boo.boo_person,boo.boo_event,boo.boo_mrc,boo.boo_trade,vOctType_2,
                 boo.boo_date,oTrrStartDate,oTrrEndDate,oTrrRate,chk);
                 insert into r5bookedhours
                (boo_event,boo_act,boo_trade,boo_person,boo_mrc,boo_desc,boo_routeparent,
                 boo_udfchar01,boo_udfchar02,boo_udfchar04,boo_date,
                 boo_octype,boo_on,boo_off,boo_rate,boo_udfchkbox01)
                values
                (boo.boo_event,boo.boo_act,boo.boo_trade,boo.boo_person,boo.boo_mrc,boo.boo_desc,boo.boo_routeparent,
                 boo.boo_udfchar01,boo.boo_code,vSpiltTimeStamp,boo.boo_date,
                 vOctType_2,vBooOn_2,vBooOff_2,oTrrRate,'+');
              end if;
                  
           end if;  --If 3
            
            
        vNewPoint:= rec_bur.bur_off; --set for next start point
        exit when vNewPoint > boo.boo_off;
        end loop;
  exception 
    when err_val then
      update r5bookedhours set boo_udfchar02 = substr('Err: '||iErrMsg,1,80),boo_udfchar04 = vSpiltTimeStamp where boo_code = boo.boo_code;
      continue; 
    when others then
      iErrMsg := SQLERRM;
      update r5bookedhours set boo_udfchar02 =  substr('Err: '||iErrMsg, 1, 80),boo_udfchar04 = vSpiltTimeStamp where boo_code = boo.boo_code;
      continue;   end;
  end loop; --end loop for cur_boo
 
  update r5objects set obj_udfchar22 = null where rowid=:rowid and obj_udfchar22 like 'FUNSPILT%';
  end if;

EXCEPTION
WHEN err_val THEN
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;  
end;
