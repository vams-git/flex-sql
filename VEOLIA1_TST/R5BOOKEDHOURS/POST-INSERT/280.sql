declare
  boo             r5bookedhours%rowtype;
 
  ICOSTCENTER     R5ACCOUNTDETAIL.ACD_SEGMENT1%TYPE := NULL;
  IWBS            R5ACCOUNTDETAIL.ACD_SEGMENT2%TYPE := NULL;
  IPROFITCENTER   R5ACCOUNTDETAIL.ACD_SEGMENT3%TYPE := NULL;
  IGLCODE         R5ACCOUNTDETAIL.ACD_SEGMENT4%TYPE := '90119240'; -- HARD CODE HERE, INFUTURE CONSIDER MOVE TO GL CONF
  IORGCODE        R5EVENTS.EVT_ORG%TYPE;
  ICOUNT          NUMBER;
  IRATE           R5TRADERATES.TRR_NTRATE%TYPE;
  IWOCOMPANYCODE  R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;
  IPERCOMPANYCODE R5ACCOUNTDETAIL.ACD_USRATTR4%TYPE;
  IUSRATTR3       R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;
  IUSRATTR4       R5ACCOUNTDETAIL.ACD_USRATTR4%TYPE;

  IGLGENERATE     NUMBER := 1 ;
  checkresult          VARCHAR2( 4 );
  vPerCostCode         r5personnel.per_costcode%type;

begin
 select * into boo from r5bookedhours where rowid=:rowid;
 update r5bookedhours
 set boo_jecategory ='RFBU',
 boo_jesource = 'GAMA'
 where rowid = :rowid
 and (boo_jecategory is null or boo_jesource is null);
 
 if boo.boo_person is not null then
   BEGIN
      SELECT EVT_ORG
      INTO IORGCODE
      FROM R5EVENTS EVT, R5ORGANIZATION ORG
      WHERE EVT_CODE = BOO.BOO_EVENT
      AND EVT.EVT_ORG = ORG.ORG_CODE
      AND  ORG.ORG_UDFCHAR09 IS NOT NULL ;
   EXCEPTION WHEN NO_DATA_FOUND THEN
      IGLGENERATE := 0;
   END;
   
   IF IGLGENERATE = 1 THEN --1
      IF IORGCODE NOT IN ('WAU','NWA') THEN
          BEGIN
            SELECT NVL(TRR.trr_ntrate, 0)
            INTO IRATE
            FROM R5PERSONNEL PER,
                 (SELECT TRR_PERSON, TRR_NTRATE,TRR_OCTYPE
                    FROM R5TRADERATES
                   WHERE TRR_MRC LIKE '%-SAP'
                     AND TRUNC(SYSDATE) BETWEEN TRR_START AND TRR_END
                     ) TRR
            WHERE PER.PER_CODE = BOO.BOO_PERSON
            AND PER.PER_COSTCODE IS NOT NULL
            AND TRR.TRR_PERSON = BOO.BOO_PERSON
            AND TRR.TRR_OCTYPE = BOO.BOO_OCTYPE;
            IF IRATE <> 0 THEN
              ICOUNT := 1;
            ELSE
              ICOUNT := 0;
            END IF;
         EXCEPTION WHEN NO_DATA_FOUND THEN
            ICOUNT := 0;
         END;
     ELSE
         begin
           select per_costcode into vPerCostCode
           from r5personnel
           where per_code = boo.boo_person
           and per_costcode is not null;
           
           
           IRATE:= o7boora1( 
           IORGCODE||'-SAP',--cmrc,
           boo.boo_trade,--ctrade,
           boo.boo_octype,--cbookedoctype,
           boo.boo_ocrtype,--cbookedocrtype,
           boo.boo_date,--cbookeddate,
           IORGCODE,--corg,
           boo.boo_person,--cbooperson,
           checkresult
           );
         
           IF nvl(IRATE,0) <> 0 THEN
              ICOUNT := 1;
           ELSE
              ICOUNT := 0;
           END IF;
         exception when no_data_found then
            ICOUNT := 0;
         end;
     END IF;
     
     
     IF ICOUNT = 1 THEN --1.1
        BEGIN
           SELECT SUBSTR(EVT.EVT_COSTCODE, INSTR(EVT.EVT_COSTCODE, '-') + 1),
                  SUBSTR(EVT.EVT_COSTCODE, 1, INSTR(EVT.EVT_COSTCODE, '-') - 1)
           INTO IWBS, IWOCOMPANYCODE
           FROM R5EVENTS EVT
           WHERE EVT_CODE = BOO.BOO_EVENT;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLEASE NOTE, NEED CONSIDER HOW TO CONTROL IF NO SAP INFORMATION FOR THE EVENTS
        END;
        BEGIN
            SELECT PER.PER_COSTCODE,
                   SUBSTR(PER.PER_COSTCODE, 1, INSTR(PER.PER_COSTCODE, '-') - 1)
            INTO ICOSTCENTER, IPERCOMPANYCODE
            FROM R5PERSONNEL PER
            WHERE PER.PER_CODE = BOO.BOO_PERSON;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLEASE NOTE, NEED CONSIDER HOW TO CONTROL IF NO SAP INFORMATION FOR THE EMPLOYEE
        END;
        
        IF BOO.BOO_CORRECTION = '-' THEN
          --IF :NEW.BOO_COST > 0  THEN
          ICOSTCENTER := NULL;
          IF IWOCOMPANYCODE != IPERCOMPANYCODE THEN
            IUSRATTR3 := IWOCOMPANYCODE;
            IUSRATTR4 := IPERCOMPANYCODE;
          ELSE
            IUSRATTR3 := IWOCOMPANYCODE;--NULL;
            IUSRATTR4 := IPERCOMPANYCODE;
          END IF;
          select nvl(org_udfchar01,'90119240') into IGLCODE
          from   r5organization
          where  org_code = IORGCODE;
        ELSE
          IWBS := NULL;
          IF IWOCOMPANYCODE != IPERCOMPANYCODE THEN
            IUSRATTR3 := IPERCOMPANYCODE;
            IUSRATTR4 := IWOCOMPANYCODE;
          ELSE
            IUSRATTR3 := IPERCOMPANYCODE;--NULL;
            IUSRATTR4 := IWOCOMPANYCODE;
          END IF;
          select nvl(org_udfchar02,'90119240') into IGLCODE
          from   r5organization
          where  org_code = IORGCODE;
        END IF;
        -- R5O7.O7MAXSEQ ( CCALC =>  IACCOUNT, CECALC => 1, CETYPE => 'ACCOUNT', CHK => ICHK ) ;
        
        
        
        INSERT INTO R5ACCOUNTDETAIL
        (ACD_CODE,
         ACD_RENTITY,
         ACD_SEGMENT1,
         ACD_SEGMENT2,
         ACD_SEGMENT3,
         ACD_SEGMENT4,
         ACD_USRATTR1,
         ACD_USRATTR2,
         ACD_USRATTR3,
         ACD_USRATTR4)
      VALUES
        (BOO.BOO_ACD,
         'BOOK',
         ICOSTCENTER,
         IWBS,
         IPROFITCENTER,
         IGLCODE,
         IORGCODE,
         IRATE,
         IUSRATTR3, -- COMPANY CODE FOR DEBIT
         IUSRATTR4 -- CPMPANY CODE FOR CREDIT
         );

    
     END IF;  --1.1
     
     
   END IF; --1
 
 end if;
 

   
exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/235' ||SQLCODE || SQLERRM);
end;
