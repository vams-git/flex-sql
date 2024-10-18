DECLARE
e_NO_ASSET      exception;
e_NO_FCODE      exception;
e_ERR_FMODE     exception;
e_ERR_CAUSE     exception;
e_ERR_FEFFECT   exception;
e_ERR_SAFETYOBJ exception;
e_ERR_PRODCRITCAL exception;
e_ERR_ACTION      exception;
e_ERR_INSTRUCTION exception;
e_ERR_TEMPLATE    exception;
e_ERR_INTERVAL    exception;
e_ERR_PERIOD      exception;
e_ERR_TRADE       exception;
e_ERR_SPARE       exception;
e_ERR_PM          exception;
e_NO_USER         exception;

e_NO_PPM         exception;
e_NO_DEPT         exception;
e_NO_PPM_ACT	exception;
e_NO_PPM_TASK  exception;
vFailureEffect    varchar2(400);
C1 R5TRACKINGDATA%ROWTYPE;
i_count		int;
vEnabledEnhancedPlanning 	VARCHAR2(1);
vHours			r5tasks.tsk_hours%TYPE;
vPersons			r5tasks.tsk_persons%TYPE;

BEGIN

i_count :=0;
SELECT * INTO C1 FROM R5TRACKINGDATA
WHERE ROWID = :ROWID;

IF C1.TKD_TRANS = 'FMEA' THEN 

    SELECT COUNT(1) INTO i_count
    FROM R5OBJECTS
    WHERE OBJ_CODE = C1.TKD_PROMPTDATA1
    AND   OBJ_ORG = C1.TKD_PROMPTDATA2
    AND   OBJ_OBRTYPE ='A';
    IF i_count = 0 THEN
       RAISE e_NO_ASSET;
    END IF;

    select COUNT(1) INTO i_count
    from r5failures
    where fal_notused ='-'
    and (fal_gen ='+'
    or
    (fal_gen = '-' and
    exists (select 1 from r5failureclasses,r5objects
    where fca_failure = fal_code
    and   fca_class = obj_class and fca_class_org = obj_class_org
    and   obj_code = C1.TKD_PROMPTDATA1 and obj_org = C1.TKD_PROMPTDATA2)
    ))
    AND FAL_CODE = C1.TKD_PROMPTDATA3;
    IF i_count = 0 THEN
       RAISE e_NO_FCODE;
    END IF;

    IF C1.TKD_PROMPTDATA4 IS NULL OR LENGTH(C1.TKD_PROMPTDATA4) > 80 THEN
       RAISE e_ERR_FMODE;
    END IF;

   /* IF C1.TKD_PROMPTDATA5 IS NULL OR LENGTH(C1.TKD_PROMPTDATA5) > 80 THEN
       RAISE e_ERR_CAUSE;
    END IF;*/

    /*IF C1.TKD_PROMPTDATA6 IS NULL OR LENGTH(C1.TKD_PROMPTDATA6) > 80 THEN
       RAISE e_ERR_FEFFECT;
    END IF;*/

    IF C1.TKD_PROMPTDATA6 not in ('-','+') THEN
       RAISE e_ERR_SAFETYOBJ;
    END IF;

    IF C1.TKD_PROMPTDATA7 not in ('-','+') THEN
       RAISE e_ERR_PRODCRITCAL;
    END IF;

    if C1.TKD_PROMPTDATA8 is not null then
      IF UPPER(C1.TKD_PROMPTDATA8) not in ('ADD TASK','MODIFY TASK','REMOVE TASK','NO ACTION') THEN
         RAISE e_ERR_ACTION;
      END IF;
    end if;


    IF C1.TKD_PROMPTDATA9 IS NOT NULL THEN
      IF LENGTH(C1.TKD_PROMPTDATA9) > 80 THEN
         RAISE e_ERR_TEMPLATE;
      END IF;
    END IF;

    IF C1.TKD_PROMPTDATA10 IS NOT NULL THEN
      BEGIN
        i_count := TO_NUMBER(C1.TKD_PROMPTDATA10);
      EXCEPTION WHEN OTHERS THEN
        RAISE e_ERR_INTERVAL;
      END;
    END IF;

    IF C1.TKD_PROMPTDATA11 IS NOT NULL THEN
      IF UPPER(C1.TKD_PROMPTDATA11) not in ('HOUR(S)','DAY(S)','WEEK(S)','MONTH(S)','YEAR(S)') THEN
         RAISE e_ERR_PERIOD;
      END IF;
    END IF;

    IF C1.TKD_PROMPTDATA12 IS NOT NULL THEN
      SELECT COUNT(1) INTO i_count
      FROM R5TRADES
      where trd_notused ='-'
      AND TRD_CODE = C1.TKD_PROMPTDATA12;
      IF i_count = 0 THEN
        RAISE e_ERR_TRADE;
      END IF;
    END IF;

    IF C1.TKD_PROMPTDATA13 IS NOT NULL THEN
      IF C1.TKD_PROMPTDATA13 not in ('-','+') THEN
         RAISE e_ERR_SPARE;
      END IF;
    ELSE
      C1.TKD_PROMPTDATA13 := '-';
    END IF;

    IF C1.TKD_PROMPTDATA14 IS NOT NULL THEN
       SELECT COUNT(1) INTO i_count
       FROM r5ppms
       WHERE ppm_notused ='-'
       AND ppm_org = C1.TKD_PROMPTDATA2
       AND PPM_CODE = C1.TKD_PROMPTDATA14;
       IF i_count = 0 THEN
          RAISE e_ERR_PM;
       END IF;
    END IF;


    select COUNT(1) INTO i_count
    from R5USERS
    where USR_CODE = C1.TKD_PROMPTDATA15;
    IF i_count = 0 THEN
       RAISE e_NO_USER;
    END IF;

    vFailureEffect := C1.TKD_PROMPTDATA46 ||
                      C1.TKD_PROMPTDATA47 ||
                      C1.TKD_PROMPTDATA48 ||
                      C1.TKD_PROMPTDATA49 ||
                      C1.TKD_PROMPTDATA50;


    IF C1.TKD_PROMPTDATA51 IS NOT NULL THEN
      IF LENGTH(C1.TKD_PROMPTDATA51) > 4000 THEN
         RAISE e_ERR_INSTRUCTION;
      END IF;
    END IF;

    select count(1) into i_count
    from U5OUFMEA
    WHERE OUF_OBJECT     =  C1.TKD_PROMPTDATA1
    AND   OUF_OBJECT_ORG =  C1.TKD_PROMPTDATA2
    AND   OUF_FAILURE    =  C1.TKD_PROMPTDATA3
    AND   OUF_FAILUREMODE = C1.TKD_PROMPTDATA4;

    if i_count = 0 then
       insert into U5OUFMEA
       (OUF_OBJECT,
        OUF_OBJECT_ORG,
        OUF_FAILURE,
        OUF_FAILUREMODE,
        OUF_CAUSE,
        OUF_FAILUREEFFECT,
        OUF_SAFETYOBJ,
        OUF_PRODCRITCAL,
        OUF_ACTION,
        OUF_INSTRUCTION,
        OUF_TEMPLATE,
        OUF_INTERVAL,
        OUF_PERIOD,
        OUF_TRADE,
        OUF_SPARE,
        OUF_PPM,
        OUF_CREATEDBY,
        OUF_CREATED,
        CREATEDBY,
        CREATED,
        UPDATEDBY,
        UPDATED,
        UPDATECOUNT)
        VALUES
        (C1.TKD_PROMPTDATA1,
         C1.TKD_PROMPTDATA2,
         C1.TKD_PROMPTDATA3,
         C1.TKD_PROMPTDATA4,
         C1.TKD_PROMPTDATA5,
         vFailureEffect,
         C1.TKD_PROMPTDATA6,
         C1.TKD_PROMPTDATA7,
         UPPER(C1.TKD_PROMPTDATA8),
         C1.TKD_PROMPTDATA51,
         C1.TKD_PROMPTDATA9,
         C1.TKD_PROMPTDATA10,
         UPPER(C1.TKD_PROMPTDATA11),
         C1.TKD_PROMPTDATA12,
         C1.TKD_PROMPTDATA13,
         C1.TKD_PROMPTDATA14,
         C1.TKD_PROMPTDATA15,
         O7GTTIME(C1.TKD_PROMPTDATA2),
         C1.TKD_PROMPTDATA15,
         SYSDATE,
         NULL,
         NULL,
         0);

    else
       UPDATE U5OUFMEA SET
       OUF_CAUSE          = C1.TKD_PROMPTDATA5,
       OUF_FAILUREEFFECT  = vFailureEffect,
       OUF_SAFETYOBJ      = C1.TKD_PROMPTDATA6,
       OUF_PRODCRITCAL    = C1.TKD_PROMPTDATA7,
       OUF_ACTION         = UPPER(C1.TKD_PROMPTDATA8),
       OUF_INSTRUCTION    = C1.TKD_PROMPTDATA51,
       OUF_TEMPLATE       = C1.TKD_PROMPTDATA9,
       OUF_INTERVAL       = C1.TKD_PROMPTDATA10,
       OUF_PERIOD         = UPPER(C1.TKD_PROMPTDATA11),
       OUF_TRADE          = C1.TKD_PROMPTDATA12,
       OUF_SPARE          = C1.TKD_PROMPTDATA13,
       OUF_PPM            = C1.TKD_PROMPTDATA14,
       UPDATEDBY          = C1.TKD_PROMPTDATA15,
       UPDATED            = SYSDATE
       WHERE OUF_OBJECT     =  C1.TKD_PROMPTDATA1
       AND   OUF_OBJECT_ORG =  C1.TKD_PROMPTDATA2
       AND   OUF_FAILURE    =  C1.TKD_PROMPTDATA3
       AND   OUF_FAILUREMODE = C1.TKD_PROMPTDATA4;
    end if;

    o7interface.trkdel(C1.TKD_TRANSID);
	
ELSIF C1.TKD_TRANS = 'PPMS' THEN 
	
	SELECT COUNT(1) INTO i_count FROM r5ppms
	WHERE  ppm_code = C1.TKD_PROMPTDATA1
	AND ppm_org = C1.TKD_PROMPTDATA2;
	IF i_count = 0 THEN
		RAISE e_NO_PPM;
	END IF;
	
	SELECT COUNT(1) INTO i_count FROM r5mrcs 
	WHERE  mrc_code = C1.TKD_PROMPTDATA3
	AND mrc_org = C1.TKD_PROMPTDATA2;
	IF i_count = 0 THEN
		RAISE e_NO_DEPT;
	END IF;
	
	UPDATE r5ppms SET PPM_UDFCHAR29=C1.TKD_PROMPTDATA3, PPM_UDFCHKBOX05=C1.TKD_PROMPTDATA4, PPM_UDFCHAR23=C1.TKD_PROMPTDATA5
	WHERE ppm_code = C1.TKD_PROMPTDATA1
	AND ppm_org = C1.TKD_PROMPTDATA2;
	
	o7interface.trkdel(C1.TKD_TRANSID);
	
ELSIF C1.TKD_TRANS = 'PPAS' THEN 	
	
	SELECT COUNT(1) INTO i_count FROM r5ppms
	WHERE  ppm_code = C1.TKD_PROMPTDATA1
	AND ppm_org = C1.TKD_PROMPTDATA2;
	IF i_count = 0 THEN
		RAISE e_NO_PPM;
	END IF;
	
	SELECT COUNT(1) INTO i_count FROM R5PPMACTS
	WHERE  ppa_ppm = C1.TKD_PROMPTDATA1
	AND ppa_act = C1.TKD_PROMPTDATA3;
	IF i_count = 0 THEN
		RAISE e_NO_PPM_ACT;
	END IF;
	
	vEnabledEnhancedPlanning := '-';
	IF C1.TKD_PROMPTDATA6 IS NOT NULL THEN 
		SELECT COUNT(1) INTO i_count FROM r5tasks
		WHERE tsk_code  = C1.TKD_PROMPTDATA6
		AND tsk_revision = 0
		AND NVL(TSK_NOTUSED,'-') = '-';
		IF i_count = 0 THEN
			RAISE e_NO_PPM_TASK;
		END IF;
	
		SELECT tsk_enableenhancedplanning,tsk_hours,tsk_persons 
		INTO vEnabledEnhancedPlanning,vHours,vPersons 
		FROM r5tasks 
		WHERE tsk_code = C1.TKD_PROMPTDATA6
		AND tsk_revision = 0;
	END IF;
	
	UPDATE R5PPMACTS SET PPA_UDFCHKBOX01=  C1.TKD_PROMPTDATA4,PPA_UDFCHAR30=C1.TKD_PROMPTDATA5,
	PPA_TASK = C1.TKD_PROMPTDATA6, ppa_qty = 1,
	PPA_EST = CASE WHEN NVL(vEnabledEnhancedPlanning,'-') = '+' AND C1.TKD_PROMPTDATA6 IS NOT NULL THEN vHours ELSE  PPA_EST END,
	PPA_PERSONS = CASE WHEN NVL(vEnabledEnhancedPlanning,'-') = '+' AND  C1.TKD_PROMPTDATA6 IS NOT NULL THEN vPersons ELSE PPA_PERSONS END
	WHERE  ppa_ppm = C1.TKD_PROMPTDATA1
	AND ppa_act = C1.TKD_PROMPTDATA3;
	
	o7interface.trkdel(C1.TKD_TRANSID);
	
ELSIF C1.TKD_TRANS = 'PPES' THEN 
	
	SELECT COUNT(1) INTO i_count FROM r5ppms
	WHERE  ppm_code = C1.TKD_PROMPTDATA1
	AND ppm_org = C1.TKD_PROMPTDATA2;
	IF i_count = 0 THEN
		RAISE e_NO_PPM;
	END IF;
	
	SELECT COUNT(1) INTO i_count FROM r5objects 
	WHERE  obj_code = C1.TKD_PROMPTDATA3
	AND obj_org = C1.TKD_PROMPTDATA2;
	IF i_count = 0 THEN
		RAISE e_NO_DEPT;
	END IF;
	
END IF;

    EXCEPTION
     WHEN e_NO_ASSET THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the Asset information');
     WHEN e_NO_FCODE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the FailureCode information');
     WHEN e_ERR_FMODE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Failure Mode is mandatory and maixmum length is 80');
     WHEN e_ERR_CAUSE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Cause is mandatory and maixmum length is 80');
     WHEN e_ERR_FEFFECT THEN
          RAISE_APPLICATION_ERROR(-20005, 'Failure Effect is mandatory and maixmum length is 80');
     WHEN e_ERR_SAFETYOBJ THEN
          RAISE_APPLICATION_ERROR(-20005, 'Safety Enviroment Critical vaule must be - or +');
     WHEN e_ERR_PRODCRITCAL THEN
          RAISE_APPLICATION_ERROR(-20005, 'Production Critical vaule must be - or +');
     WHEN e_ERR_ACTION THEN
          RAISE_APPLICATION_ERROR(-20005, 'Action value must be ADD TASK,MOIDFY TASK,REMOVE TASK or NO ACTION');
     WHEN e_ERR_INSTRUCTION THEN
          RAISE_APPLICATION_ERROR(-20005, 'Proposed Routine Instructions maixmum length is 4000');
     WHEN e_ERR_TEMPLATE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Template maixmum length is 80');
     WHEN e_ERR_INTERVAL THEN
          RAISE_APPLICATION_ERROR(-20005, 'Interval must be numeric');
     WHEN e_ERR_PERIOD THEN
          RAISE_APPLICATION_ERROR(-20005, 'Period value must be DAYD(S),WEEK(S),MONTH(S) or YEAR(S)');
     WHEN e_ERR_TRADE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Cannot find Trade information');
     WHEN e_ERR_SPARE THEN
          RAISE_APPLICATION_ERROR(-20005, 'Spare vaule must be - or +');
     WHEN e_ERR_PM THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the PM Schedule information');
     WHEN e_NO_USER THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the User information');
	WHEN e_NO_PPM THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the PM Schedule information');
	WHEN e_NO_DEPT THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the Department information');
	WHEN e_NO_PPM_ACT THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the PM Schedule Activity information');
	WHEN e_NO_PPM_TASK THEN
          RAISE_APPLICATION_ERROR(-20005, 'Can not find the Activity Task information');
    WHEN NO_DATA_FOUND then
         null;
     WHEN OTHERS then
          RAISE_APPLICATION_ERROR(-20005, SQLCODE || SQLERRM);
  END;