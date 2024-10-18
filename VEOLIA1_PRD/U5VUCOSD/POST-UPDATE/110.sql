declare 
  ucd        u5vucosd%rowtype;
  vSelRegn   varchar2(15);
  vSelOrg    varchar2(15);
  
  cursor cur_org (vRegn in varchar2,vOrg in varchar2) is 
  select org_code from r5organization
  where org_common ='-' and nvl(org_udfchar10,'NA') not in ('NOT IN USED') 
  and org_udfchar03 = vRegn
  and org_code like vOrg;
  
  p_selorg      varchar2(15);
  p_selend      date;
  p_sessionid   number;
  p_selinkit    varchar2(1);
  p_selrelmps   varchar2(1);
  
  v_due         DATE;
  v_meterdue    NUMBER;
  v_dormstart   DATE;
  v_dormend     DATE;
  v_chk         VARCHAR2(1);
  v_cnt         NUMBER;
  v_countit2    NUMBER;
  v_jobno       NUMBER;
  curseq        NUMBER;
  nextseq       NUMBER;
  freq          NUMBER;
  perioduom     r5uoms.uom_code%TYPE;
  wodesc        r5patternsequences.psq_wodesc%TYPE;
  psqmeter      r5patternsequences.psq_meter%type;
  psqpk         r5patternsequences.psq_pk%type;
  psqstw        r5patternsequences.psq_standwork%type;
  dppmcal       DATE;
  checkresult   VARCHAR2(4);
  cancstat      r5install.ins_desc%TYPE := o7dflt( 'CANCSTAT', checkresult );
  
  vObjDailyUsg      r5objusagedefs.oud_dfltdailyusg%type;
  vLastReaDate      r5readings.rea_date%type;
  vLastReading      r5readings.rea_reading%type;
  vMeterFreq        number;
               
  
  vActEst           number;
  vWOClass          r5events.evt_class%type;
  
  v_ErrMsg          varchar2(150);
  v_Err              exception;
  
  CURSOR OBJ IS
  SELECT    o.ppo_ppm,
            p.ppm_revision,
            p.ppm_freq,
            o.ppo_pk,
            o.ppo_object,
            o.ppo_object_org,
            o.ppo_route,
            o7gtdate( o.ppo_due, o.ppo_performonweek, o.ppo_performonday ) ppo_due,
            o.ppo_obtype,
            o.ppo_obrtype,
            COALESCE( o.ppo_mrc, b.obj_pmwodept, b.obj_mrc ) ppo_mrc,
            p.ppm_duration,
            o.ppo_freq,
            p.ppm_nested,
            o.ppo_perioduom,
            p.ppm_nestedtolmin,
            p.ppm_nestedtolmax,
            o.ppo_dormstart,
            o.ppo_dormend,
            o.ppo_dormreuse,
            o.ppo_deactive,
            o.ppo_performonweek,
            o.ppo_performonday,
            o.ppo_meter,
            o.ppo_metuom,
            o.ppo_meterdue,
            o.ppo_isstype    
  FROM      r5ppms p,
            r5ppmobjects o,
            r5objects b
  WHERE   b.obj_code     = o.ppo_object
  AND     b.obj_org      = o.ppo_object_org
  AND     p.ppm_code     = o.ppo_ppm
  AND     p.ppm_revision = o.ppo_revision
  AND     p.ppm_package  = '-'
  --AND     o.ppo_isstype  = 'D'
  AND     p.ppm_notused  = '-'
  AND     p.ppm_revision = ( SELECT MAX( p2.ppm_revision )
                             FROM r5ppms P2
                             WHERE    p2.ppm_code       = p.ppm_code
                             AND    p2.ppm_revrstatus = 'A' )
  AND     o7gtdate( o.ppo_due, o.ppo_performonweek, o.ppo_performonday ) <= NVL( p_selend , sysdate + 10000 )
  AND     o.ppo_org = p_selorg  
  --AND     ppm_code ='KUR-KDP-R-0583'
  --ORDER BY ppm_freq DESC;
  order by ppo_ppm;
  
  CURSOR chk_calendar ( cppm VARCHAR2, nppmrev NUMBER, cobject VARCHAR2, cobjectorg VARCHAR2, due DATE ) IS
  SELECT add_months( p.ppc_date, 12 * ( r.rpn_line - 1 ) )
  FROM   r5repnum r, r5ppmcalendars p
  WHERE  p.ppc_ppm        = cppm
  AND    p.ppc_revision   = nppmrev
  AND    p.ppc_object     = cobject
  AND    p.ppc_object_org = cobjectorg
  AND    add_months( p.ppc_date, 12 * ( r.rpn_line - 1 ) ) >= TRUNC( due )
  AND  ( r.rpn_line = 1 or p.ppc_reuse = '+' )
  ORDER BY 1;
  
  CURSOR mtp( cs VARCHAR2 ) IS
  SELECT DISTINCT mtp_code,
         mtp_org,
         mtp_revision,
         mtp_mptype,
         evt_object,
         evt_object_org,
         peq_route,
         evt_due,
         evt_mp_seq,
         peq_dormstart,
         peq_dormend,
         peq_dormreuse,
         peq_deactive,
         peq_org,
         m.mtp_metuom,
         m.mtp_releasetype,
         evt_meterdue,
         evt_meterduedate,
         evt_mrc,
         peq_person
  FROM   r5maintenancepatterns m,
         r5patternequipment,
         r5events
  WHERE  mtp_code       = peq_mp
  AND    mtp_org        = peq_mp_org
  AND    mtp_revision   = peq_revision
  AND    peq_mp         = evt_mp
  AND    peq_mp_org     = evt_mp_org
  AND    peq_object     = evt_object
  AND    peq_object_org = evt_object_org
  AND    peq_status     = 'A'
  AND    evt_status    <> NVL( cs, 'x' )
  AND    evt_due = ( SELECT MAX(nvl(evt_due,evt_start))
                     FROM   r5events
                     WHERE  evt_mp         = peq_mp
                     AND    evt_mp_org     = mtp_org
                     AND    evt_object     = peq_object
                     AND    evt_object_org = peq_object_org
                     AND    evt_status    <> NVL( cs, 'x' ) )
  --AND    mtp_allowduplicatewo = '+'
  AND    evt_due < p_selend
  AND    peq_object_org = p_selorg  
  --and    mtp_code = 'KUR-CXU-T0001'
  ORDER BY mtp_code DESC;

  /* Cursor to retrieve next sequence. */
  CURSOR psq( curmp VARCHAR2, curmporg VARCHAR2, curmprev NUMBER, curseq NUMBER ) IS
  SELECT MIN( psq_sequence )
  FROM   r5patternsequences
  WHERE  psq_mp       = curmp
  AND    psq_mp_org   = curmporg
  AND    psq_revision = curmprev
  AND    psq_sequence > curseq
  AND    psq_notused  = '-';

  /* Cursor to retrieve pattern sequence data. */
  CURSOR psq2( curmp VARCHAR2, curmporg VARCHAR2, curmprev NUMBER, curseq NUMBER ) IS
  SELECT psq_freq, psq_perioduom, psq_wodesc,ps.psq_meter,ps.psq_pk,ps.psq_standwork
  FROM   r5patternsequences ps
  WHERE  psq_mp        = curmp
  AND    psq_mp_org    = curmporg
  AND    psq_revision  = curmprev
  AND    psq_sequence  = curseq
  AND    psq_notused   = '-';
  
  /* Local procedure creates dummy job in r5tempwmbwog. */
Procedure x5CrTEvt(
  p_neweventno    IN       VARCHAR2,
  p_ppmcode       IN       VARCHAR2,
  p_revision      IN       NUMBER,
  p_ppo_pk        IN       NUMBER,
  p_due           IN       DATE,
  p_meterdue      IN       NUMBER,
  p_ppopk         IN       VARCHAR2,
  p_sessionid     IN       NUMBER,
  p_selinkit      IN       VARCHAR2,
  p_chk           OUT      VARCHAR2 )   IS

  v_ppmrev          r5events.evt_ppmrev%type;       /* Approved PPM rev          */
  v_ppopk           r5events.evt_ppopk%type;        /* PPO primary key           */
  v_object          r5events.evt_object%type;       /* Object                    */
  v_objectorg       r5events.evt_object_org%type;   /* Object org.               */
  v_dcompleted      r5events.evt_completed%type;    /* Date completed            */
  v_freq            r5events.evt_freq%type;         /* Frequenty                 */
  v_org             r5organization.org_code%TYPE;   /* Org of event or ppm       */
  v_status          r5objects.obj_status%TYPE;      /* Status of the object      */
  v_rstatus         r5objects.obj_rstatus%TYPE;     /* System Status of the obj. */
  v_ppodeactive     DATE;                           /* PO deactivation date      */
  v_revision        r5ppms.ppm_revision%TYPE;       /* PM approved revision      */
  v_ActEst          number;
  
 

  chk      VARCHAR2( 4 );
  syskit1  VARCHAR2( 30 ) := o7dflt( 'SYSKIT1', chk );

  CURSOR c_ppm ( code VARCHAR2 ) IS
    SELECT ppm_revision
    FROM   r5ppms
    WHERE  ppm_code       = code
    AND    ppm_revrstatus = 'A';

BEGIN
  /* Initialize */
  p_chk     := '0';

  BEGIN
    SELECT p.ppo_object,
           p.ppo_object_org,
           p.ppo_pk,
           p.ppo_deactive,
           p.ppo_org
    INTO   v_object,
           v_objectorg,
           v_ppopk,
           v_ppodeactive,
           v_org
    FROM   r5ppmobjects p
    WHERE  p.ppo_pk       = p_ppo_pk
    AND    p.ppo_ppm      = p_ppmcode
    AND    p.ppo_revision = p_revision;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
  /* Invalid event number */
      p_chk := '15';
      RETURN;
  END;

  /* Check whether Equipment status is withdrawn */
  SELECT obj_rstatus, obj_status
  INTO   v_rstatus, v_status
  FROM   r5objects
  WHERE  obj_code = v_object
  AND    obj_org  = v_objectorg;

  IF v_rstatus = 'D' THEN
    IF p_selinkit = '-' OR syskit1 <> v_status THEN
      RETURN;
    END IF;
  END IF;

  /* Check whether PM should be deactivated */
  IF NVL( TRUNC( v_ppodeactive, 'DD' ), o7gttime( v_org) + 1 ) <= TRUNC( o7gttime( v_org), 'DD' ) THEN
    p_chk := '0';
    RETURN;
  END IF;

  /* Get approved PM revision number */
  OPEN  c_ppm ( p_ppmcode );
  FETCH c_ppm INTO v_revision;
  CLOSE c_ppm;

  
  insert into u5wupmfc
  (upf_sessionid,upf_org,upf_code,upf_ppm,upf_ppopk,upf_desc,upf_status,upf_object,upf_object_org,upf_isstype,upf_ppm_revision,
   upf_due,upf_target,upf_freq,upf_perioduom,
   upf_meterdue,upf_meter,upf_metuom,
   upf_actest,upf_woclass,upf_mrc,upf_person,upf_route,
   upf_due_year,upf_due_week,
   upf_bypassed,upf_created,createdby,created,updatecount)
  select 
  p_sessionid,ppo_object_org,'WOG' || p_neweventno,p.ppm_code,p_ppopk,p.ppm_desc,'A',m.ppo_object,m.ppo_object_org,m.ppo_isstype,m.ppo_revision,
  p_due,p_due,m.ppo_freq,m.ppo_perioduom, --o7gtfreq( m.ppo_freq, m.ppo_perioduom, sysdate ) get freq in days
  p_meterdue,m.ppo_meter,m.ppo_metuom,
  (SELECT
    sum(decode(ppa_udfchkbox01,'+',
  CASE WHEN COALESCE(tsk_enableenhancedplanning, '-') = '+' THEN tsk_hours*nvl(ppa_qty,1) ELSE ppa_est END
   *
  decode(ppo_route,null,1,(select count(1) from r5routobjects,r5objects
  where  rob_object=obj_code and rob_object_org=obj_org
  and    obj_rstatus='I'
  and    rob_route= ppo_route)),
  CASE WHEN COALESCE(tsk_enableenhancedplanning, '-') = '+' THEN tsk_hours*nvl(ppa_qty,1) ELSE ppa_est END))
  FROM R5PPMACTS pa LEFT OUTER JOIN  r5tasks ON pa.ppa_task = tsk_code AND tsk_revrstatus ='A'
  WHERE PPA_PPM = ppm_code
  AND PPA_REVISION = ppa_revision
  ),
  m.ppo_class,m.ppo_mrc,m.ppo_person,m.ppo_route,
  to_char(p_due,'IY'),to_char(p_due,'IW'),
  '-',sysdate,'MIGRATION',sysdate,0
  FROM   r5ppms           p,
         r5ppmobjects     m,
         r5objects        a
  WHERE  p.ppm_code          = p_ppmcode
  AND    p.ppm_revision      = p_revision
  AND    m.ppo_pk            = p_ppopk
  AND    p.ppm_code          = m.ppo_ppm
  AND    p.ppm_revision      = m.ppo_revision
  AND    a.obj_code          = m.ppo_object
  AND    a.obj_org           = m.ppo_object_org; 

  RETURN;

END x5CrTEvt;

begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id in (11,12,13,14,15,16,17,18,19) and ucd.ucd_recalccost = '+' then
      vSelRegn := ucd.UCD_PARAM1;--'ZNSW';
      vSelOrg := '%';
      p_selrelmps := '+';--include MP
      select add_months(trunc(sysdate), 24) into p_selend from dual;

      p_selinkit := '+';
      for rec in cur_org(vSelRegn,vSelOrg)  loop
           p_selorg := rec.org_code;
           --get forecast month
           begin
             select add_months(trunc(sysdate), to_number(opa_desc) * 12) into p_selend
             from r5organizationoptions WHERE OPA_CODE='VPMFCAST' AND OPA_ORG = p_selorg;
           exception when others then
             null;
           end;
           
           v_jobno      := 0;
           select abs(S5BATCHREPORT.nextval) into p_sessionid from dual;
           --delete from r5tempwmbwog where tev_object_org = rec.org_code and tev_sessionid = p_sessionid;
           delete from u5wupmfc t where t.upf_org = rec.org_code;
           
           for v_obj in obj loop
           v_meterdue := null;
           vLastReaDate := o7gttime(vSelOrg);
           vLastReading := 0;
           vObjDailyUsg := 0;
           begin
               --For meter base PM, meter is not empty and pm type is not duplicate
               if v_obj.ppo_meter is not null and v_obj.ppo_isstype not in ('D') then
                  --check avg or est meter usage
                  select nvl(nvl(oud.oud_dfltdailyusg,oud.oud_calcdailyusg),0) into vObjDailyUsg
                  from r5objusagedefs oud
                  where oud.oud_object = v_obj.ppo_object and oud.oud_object_org = v_obj.ppo_object_org and oud.oud_uom = v_obj.ppo_metuom;
                  
                  --get first due date
                  if vObjDailyUsg > 0.5 then --if vg or est meter usage is configured, calculate due date from last reading and meter due
                     begin
                       select rea_date,rea_reading into vLastReaDate,vLastReading
                       from (
                       select r5readings.*, row_number() over (order by rea_date desc) as rn
                       from r5readings
                       where rea_object = v_obj.ppo_object and rea_object_org = v_obj.ppo_object_org and rea_uom = v_obj.ppo_metuom
                       ) where rn =1;
                     exception when no_data_found then
                       vLastReaDate := o7gttime(v_obj.ppo_object_org );
                       vLastReading := 0;
                     end;
                     --meter due is more than 0 and last reading is less than meter due then use meter freq as initial due.
                     if nvl(v_obj.ppo_meterdue,0) > 0 and v_obj.ppo_meterdue > vLastReading  then 
                        v_due := vLastReaDate + (v_obj.ppo_meterdue - vLastReading)/vObjDailyUsg;
                     end if;
                     vMeterFreq := round(v_obj.ppo_meter / vObjDailyUsg,0);
                  end if; --if vObjDailyUsg > 0 then
                  
                  --if due date is empty after calcuate from reading then get from calendar base
                  if v_due is null and v_obj.ppo_due is not null then
                     v_due := v_obj.ppo_due;
                  end if;
                  
                  v_meterdue := v_obj.ppo_Meterdue;
               else
                  --calendar base, for fixed and variable this process did not include awaitng release wo 
                  if v_obj.ppo_due is not null then
                     v_due := v_obj.ppo_due;
                  end if;
               end if;  --if v_obj.ppo_meter is not null then

               v_cnt := 1;
               
               while v_due is not null and v_due <= p_selend loop -- LOOP when next due is less than generate through 
               IF v_obj.ppo_performonweek IS NULL OR v_obj.ppo_perioduom IN ( 'D', 'W' ) THEN
                  /* Check equipment calendars. */
                  dppmcal := '';
                  OPEN  chk_calendar( v_obj.ppo_ppm, v_obj.ppm_revision, v_obj.ppo_object, v_obj.ppo_object_org, v_due );
                  FETCH chk_calendar INTO dppmcal;
                  CLOSE chk_calendar;
                  IF dppmcal <= p_selend THEN
                    v_due := dppmcal;
                  ELSIF dppmcal > p_selend THEN
                    EXIT;
                  END IF;
                END IF; -- _obj.ppo_performonweek IS NULL OR v_obj.ppo_perioduom IN ( 'D', 'W' ) 
                
                BEGIN
                  SELECT 1 INTO v_countit2 FROM dual
                  WHERE EXISTS (SELECT 1 FROM r5events
                                WHERE evt_ppopk = v_obj.ppo_pk AND evt_due = v_due and evt_status <> cancstat );
                EXCEPTION
                WHEN no_data_found THEN
                  v_dormstart := NVL( v_obj.ppo_dormstart, v_due + 100 );
                  v_dormend   := NVL( v_obj.ppo_dormend,   v_due + 100 );
                  IF v_obj.ppo_dormreuse = '+' THEN
                    WHILE v_dormend < v_due LOOP
                      v_dormstart := ADD_MONTHS( v_dormstart, 12 );
                      v_dormend   := ADD_MONTHS( v_dormend, 12 );
                    END LOOP;
                  END IF;
                  IF v_due NOT BETWEEN v_dormstart AND v_dormend AND
                    v_due < NVL( v_obj.ppo_deactive, v_due + 1 ) THEN
                   /* Only create job, if not in dormant period. */
                   v_jobno := v_jobno + 1;
                   IF (NVL( UPPER( o7dflt( 'PMCRPAST', v_chk ) ), 'NO' ) NOT IN ( '-', 'OFF', 'NO', 'N' )
                       OR v_due >= TRUNC( o7gttime( v_obj.ppo_object_org ), 'DD' ) ) THEN
                         x5CrTEvt( v_jobno,        v_obj.ppo_ppm,   v_obj.ppm_revision,
                                   v_obj.ppo_pk,   v_due,           v_meterdue,      v_obj.ppo_pk,
                                   p_sessionid,    p_selinkit,      v_chk );
                   END IF;
                 END IF;
                 v_cnt := v_cnt + 1;
                END;

                if nvl(vMeterFreq,0) > 0 then
                  v_due := v_due + vMeterFreq;
                else
                  v_due := v_due + o7gtfreq( v_obj.ppo_freq, v_obj.ppo_perioduom, v_due );
                end if;
                if v_obj.ppo_meter is not null then
                  v_meterdue := v_meterdue + v_obj.ppo_meter;
                end if;

                IF v_obj.ppo_performonweek IS NOT NULL AND v_obj.ppo_perioduom NOT IN ( 'D', 'W' ) THEN
                  v_due := o7gtdate( v_due, v_obj.ppo_performonweek, v_obj.ppo_performonday );
                END IF;
              END LOOP; -- while v_due <= p_selend loop;
           exception 
             when v_Err then
              RAISE_APPLICATION_ERROR ( -20003,v_ErrMsg) ;
             when others then
              v_ErrMsg := v_obj.ppo_ppm;
              RAISE_APPLICATION_ERROR ( -20003,v_ErrMsg) ;
           end;
           end loop; -- for v_obj in obj loop
           
           
           --mp start from here
           IF NVL(p_selrelmps,'-') = '+' THEN
              /* Duplicate Maintenance Patterns. */
              FOR i IN mtp( cancstat ) LOOP
              begin
                v_meterdue := null;
                vLastReaDate := o7gttime(vSelOrg);
                vLastReading := 0;
                vObjDailyUsg := 0;
            
                --include meter base mp here
                if i.mtp_metuom is not null then
                   v_due := nvl(i.evt_meterduedate,i.evt_due);
                   
                   --check avg or est meter usage
                   select nvl(nvl(oud.oud_dfltdailyusg,oud.oud_calcdailyusg),0) into vObjDailyUsg
                   from r5objusagedefs oud
                   where oud.oud_object = i.evt_object and oud.oud_object_org = i.evt_object_org and oud.oud_uom = i.mtp_metuom;
                   
                   --get last reading of equipment
                   begin
                     select rea_date,rea_reading into vLastReaDate,vLastReading
                     from (
                     select r5readings.*, row_number() over (order by rea_date desc) as rn
                     from r5readings
                     where rea_object = i.evt_object and rea_object_org = i.evt_object_org and rea_uom = i.mtp_metuom
                     ) where rn =1;
                   exception when no_data_found then
                     vLastReaDate := o7gttime(i.evt_object_org);
                     vLastReading := 0;
                   end;
                   
                   v_meterdue := i.evt_meterdue;
                else
                   v_due := i.evt_due;
                end if;
                
                v_cnt := 1;
                curseq := i.evt_mp_seq;
                WHILE v_due <= p_selend LOOP
                  /* Get next sequence. */
                  nextseq := NULL;
                  OPEN  psq( i.mtp_code, i.mtp_org, i.mtp_revision, curseq );
                  FETCH psq INTO nextseq;
                  CLOSE psq;
                  IF nextseq IS NULL THEN
                    IF i.mtp_mptype = 'R' THEN
                      /* Repeat, get first sequence. */
                      OPEN  psq( i.mtp_code, i.mtp_org, i.mtp_revision, -1 );
                      FETCH psq INTO nextseq;
                      CLOSE psq;
                    ELSE
                      /* No next sequence found, and not repeat, so stop! */
                      v_due := p_selend + 1;
                    END IF;
                  END IF;
                  IF nextseq IS NULL THEN
                    /* No sequence found, so stop. */
                      v_due := p_selend + 1;
                  ELSE
                    freq := NULL;
                    perioduom := NULL;
                    OPEN  psq2( i.mtp_code, i.mtp_org, i.mtp_revision, nextseq );
                    FETCH psq2 INTO freq, perioduom, wodesc,psqmeter,psqpk,psqstw;
                    CLOSE psq2;
                    --include meter base mp here
                    if i.mtp_metuom is not null and psqmeter is not null then
                       v_meterdue := v_meterdue + psqmeter;
                       if vObjDailyUsg > 0.5 then
                          vMeterFreq := round(psqmeter / vObjDailyUsg,0);
                          v_due := v_due + vMeterFreq;
                       else
                          v_due := v_due + o7gtfreq( freq, perioduom, v_due );
                       end if;
                    else --calendar base
                       v_due := v_due + o7gtfreq( freq, perioduom, v_due );
                    end if;
                    
                    --v_due := v_due + o7gtfreq( freq, perioduom, v_due );
                    curseq := nextseq;
                    IF v_due IS NULL THEN
                      v_due := p_selend + 1;
                    ELSE
                      v_dormstart := NVL( i.peq_dormstart, v_due + 100 );
                      v_dormend   := NVL( i.peq_dormend,   v_due + 100 );
                      IF i.peq_dormreuse = '+' THEN
                        WHILE v_dormend < v_due LOOP
                          v_dormstart := ADD_MONTHS( v_dormstart, 12 );
                          v_dormend   := ADD_MONTHS( v_dormend, 12 );
                        END LOOP;
                      END IF;
                      IF v_due NOT BETWEEN v_dormstart AND v_dormend AND
                        v_due < NVL( i.peq_deactive, v_due + 1 ) AND
                        v_due <= p_selend THEN
                        v_jobno := v_jobno + 1;
                        /* Do insert of parent event. 
                        INSERT INTO r5tempwmbwog( tev_code, tev_desc, tev_target, tev_object, tev_object_org, tev_isstype,
                               tev_sessionid, tev_freq, tev_org, tev_mp, tev_mp_org, tev_mp_revision, tev_mp_seq )
                        VALUES(  'WOG' || v_jobno, wodesc, v_due, i.evt_object, i.evt_object_org, 'D',
                                p_sessionid, '', i.peq_org, i.mtp_code, i.mtp_org, i.mtp_revision, curseq );
                        */
                         
      
                        vActEst:=0;
                        vWOClass := null;
                        begin
                          
                          SELECT 
                          sum(decode(wac_udfchkbox01,'+',
                          CASE WHEN COALESCE(tsk_enableenhancedplanning, '-') = '+' THEN tsk_hours*nvl(wac_qty,1) ELSE wac_est END
                           *
                          decode(i.peq_route,null,1,(select count(1) from r5routobjects,r5objects
                          where  rob_object=obj_code and rob_object_org=obj_org
                          and    obj_rstatus='I'
                          and    rob_route= i.peq_route)),
                          CASE WHEN COALESCE(tsk_enableenhancedplanning, '-') = '+' THEN tsk_hours*nvl(wac_qty,1) ELSE wac_est END)) as act_est,
                          stw_woclass 
                          into vActEst,vWOClass
                          FROM r5standworks,r5standwacts wac LEFT OUTER JOIN  r5tasks ON wac.wac_task = tsk_code AND tsk_revrstatus ='A'
                          where stw_code = wac.wac_standwork
                          and stw_code = psqstw
                          group by stw_woclass;
                        exception
                              when no_data_found then
                                null;
                              when others then
                                null;
                        end;
                        
                        insert into u5wupmfc
                        (upf_sessionid,upf_org,upf_code,upf_ppopk,upf_desc,upf_status,upf_object,upf_object_org,upf_isstype,
                         upf_mp,upf_mp_seq,upf_mp_org,upf_mp_revision,                    
                         upf_due,upf_target,upf_freq,upf_perioduom,
                         upf_meterdue,upf_meter,upf_metuom,
                         upf_actest,upf_woclass,upf_mrc,upf_person,upf_route,upf_standardwork,
                         upf_due_year,upf_due_week,
                         upf_bypassed,upf_created,createdby,created,updatecount)
                        values
                        (p_sessionid,i.evt_object_org,'WOG' || v_jobno,psqpk,wodesc,'A',i.evt_object,i.evt_object_org,'D',
                        i.mtp_code,curseq,i.mtp_org,i.mtp_revision,
                        v_due,v_due,freq,perioduom,
                        v_meterdue,psqmeter,i.mtp_metuom,
                        vActEst,vWOClass,i.evt_mrc,i.peq_person,i.peq_route,psqstw,
                        to_char(v_due,'IY'),to_char(v_due,'IW'),
                        '-',sysdate,'MIGRATION',sysdate,0);
                        
                      END IF;
                    END IF;
                  END IF;
                END LOOP; --WHILE v_due <= p_selend LOOP
              exception when v_err then
                RAISE_APPLICATION_ERROR ( -20003,v_ErrMsg);
              when others then
                NULL;
                --v_ErrMsg := i.mtp_code;
                --RAISE_APPLICATION_ERROR ( -20003,v_ErrMsg);
              end;
              END LOOP; --FOR i IN mtp( cancstat ) LOOP
           end if; --IF NVL(p_selrelmps,'-') = '+' THEN
      end loop; --for rec in cur_org(vSelOrg)  loop;
  update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;
  --E-00273455/QGC-KNC-R-4135/OUD_DFLTDAILYUSG/
  --OUD_CALCDAYS/OUD_CALCDAILYUSG
end;