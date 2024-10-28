declare
  trl             r5translines%rowtype; 
  
  ICOSTCENTER   R5ACCOUNTDETAIL.ACD_SEGMENT1%TYPE := NULL;
  IWBS          R5ACCOUNTDETAIL.ACD_SEGMENT2%TYPE := NULL;
  IPROFITCENTER R5ACCOUNTDETAIL.ACD_SEGMENT3%TYPE := NULL;
  IGLCODE       R5ACCOUNTDETAIL.ACD_SEGMENT4%TYPE;

  IORGCODE        R5TRANSACTIONS.TRA_ORG%TYPE;
  IWOCOMPANYCODE  R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;
  ISTRCOMPANYCODE R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;
  IPARCOMPANYCODE R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;

  IUSRATTR3   R5ACCOUNTDETAIL.ACD_USRATTR3%TYPE;
  IUSRATTR4   R5ACCOUNTDETAIL.ACD_USRATTR4%TYPE;
  IGLGENERATE NUMBER := 1;

  ICOUNT NUMBER;
  ICOUNT2 NUMBER;
  
  vParClass   R5PARTS.PAR_CLASS%TYPE;
  vMappingGL  R5PARTS.PAR_UDFCHAR23%TYPE;
  /****************************************************************************************************************************************
   NAME:       U5GLPROCESS_TRL
   PURPOSE:
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        24/10/2016  jshi             SAP Interface Go Live Depolyment
   1.1        07/11/2106  CXU              GL-ISSTOSTORE and GL-RECV segment 3 fix profit center update
                                           For AUS warehouse transfer use H710292500
                                           For nz  warehouse transfer use H719288000 -Chnage GL Reference for GL-RECV NZ segment 3 also
   1.2        16/11/2016  CXU              No GL should be gerenated if no profiet center/costcenter are configured for store 
                                           except tool issue or return
   1.3        16/11/2016  CXU              Tool will only gerenate GL transaction when issue or return against work order
   1.4        29/06/2017  CXU              No GL should be gerenated for DirectIssue/DirerctReturn on Parts which PAR_UDFCHAR01 <> ZSPA
   1.5        22/03/2020  CXU              No GL should be generated for bin transfer
   1.6        03/06/2021  CXU              No GL should be generated for Fuel part class
   1.7        24/08/2021  CXU              Tool Part issue/return, GL get from PAR_UDFCHAR23 instead of using fix value 51120000 for miscellaneous activities 
   1.8        20/04/2022  CXU              Exclude store to store transaction for STR_UDFCHAR01 = 'STOREGRP_NOGL'
   1.9        01/07/2022  CXU              Include Issue/Return parts against on Parent WO
   2.0        03/08/2022  CXU              Correct Codintion for STTKGAIN GL account on Line 279 for last changes
   2.1        03/08/2022  CXU              Update GL-ISSTOSTORE Debit profit code in segment 3. ION Mapping is get 3rd secion of the code, append the profit code format to DFLT-PRO-XXXXXXX
**************************************************************************************************************************************/

begin
 select * into trl from r5translines where rowid=:rowid;
 IF TRL.TRL_ROUTEREC IS NULL AND NVL(TRL.TRL_PRICE, 0) <> 0 THEN
    BEGIN
      SELECT TRA.TRA_ORG
      INTO IORGCODE
      FROM R5TRANSACTIONS TRA, R5ORGANIZATION ORG
      WHERE TRA.TRA_CODE = TRL.TRL_TRANS
      AND TRA.TRA_ORG = ORG.ORG_CODE
      AND ORG.ORG_UDFCHAR09 IS NOT NULL;
    EXCEPTION WHEN NO_DATA_FOUND THEN
       IGLGENERATE := 0;
    END;
    
    --exclude po receipt
    IF IGLGENERATE = 1 THEN
      IF TRL.TRL_RTYPE = 'RECV' AND TRL.TRL_ORDER IS NOT NULL AND
         TRL.TRL_EVENT IS NULL THEN
         IGLGENERATE := 0;
      END IF;
    END IF;
    
    --exclude bin transfer
    IF IGLGENERATE = 1 THEN
      IF TRL.TRL_RTYPE in ('RECV','I') THEN
         SELECT COUNT(1) INTO ICOUNT
         FROM R5TRANSACTIONS 
         WHERE TRA_CODE = TRL.TRL_TRANS
         AND   TRA_FROMENTITY = 'STOR' AND TRA_TOENTITY = 'STOR' 
         AND   TRA_FROMCODE =  TRA_TOCODE;
         IF ICOUNT > 0 THEN
            IGLGENERATE := 0;
         END IF;
      END IF;
    END IF;
    
    --exclude store to store transfer when str_udfchar01 = 'STOREGRP_NOGL' add on 20-Apr-2022
    IF IGLGENERATE = 1 THEN
       IF TRL.TRL_RTYPE in ('RECV','I') THEN
         SELECT COUNT(1) INTO ICOUNT
         FROM R5TRANSACTIONS 
         WHERE TRA_CODE = TRL.TRL_TRANS
         AND   TRA_FROMENTITY = 'STOR' AND TRA_TOENTITY = 'STOR' 
         AND   (
           (SELECT COUNT(1) FROM R5STORES WHERE STR_ORG = TRA_FROMCODE_ORG AND  STR_CODE = TRA_FROMCODE AND STR_UDFCHAR01 = 'STOREGRP_NOGL') > 0
           OR
           (SELECT COUNT(1) FROM R5STORES WHERE STR_ORG = TRA_TOCODE_ORG AND STR_CODE = TRA_TOCODE AND STR_UDFCHAR01 = 'STOREGRP_NOGL') > 0
         );
         IF ICOUNT > 0 THEN
            IGLGENERATE := 0;
         END IF;
      END IF;
    END IF;
    
    /*
    -- modified by cxu on Jun-29-2017-GL-DirectIssue/DirectReturn only apply 
    IF IGLGENERATE = 1 THEN
       IF :NEW.TRL_RTYPE IN ('RECV','RETN') AND :NEW.TRL_ORDER IS NOT NULL AND  :NEW.TRL_EVENT IS NOT NULL THEN
         SELECT COUNT(1)
          INTO ICOUNT
          FROM R5PARTS
         WHERE PAR_CODE = :NEW.TRL_PART
           AND PAR_ORG = :NEW.TRL_PART_ORG
           AND PAR_UDFCHAR01 IN ('ZSPA');
           IF ICOUNT = 0 THEN
              IGLGENERATE := 0;
           ELSE
              IGLGENERATE := 1;
           END IF;
       END IF;
    END IF;
   */
    
   -- Judge the part tool
  IF IGLGENERATE = 1 THEN
      IF TRL.TRL_RTYPE = 'I' AND TRL.TRL_EVENT IS NOT NULL THEN
        SELECT COUNT(1)
          INTO ICOUNT
          FROM R5PARTS
         WHERE PAR_CODE = TRL.TRL_PART
           AND PAR_ORG = TRL.TRL_PART_ORG
           AND ((PAR_TOOL IS NOT NULL AND PAR_UDFCHAR22 IS NOT NULL) OR
               (PAR_TOOL IS NULL));
        IF ICOUNT = 0 THEN
          IGLGENERATE := 0;
        ELSE
          IGLGENERATE := 1;
        END IF;
      END IF;
  END IF;
  
  --1.3 Tool will only gerenate GL transaction when issue or return against work order
  IF IGLGENERATE = 1 THEN
      SELECT COUNT(1) INTO ICOUNT2 -->0 IS ISSUE TOOL
      FROM R5PARTS 
      WHERE PAR_CODE = TRL.TRL_PART AND PAR_ORG = TRL.TRL_PART_ORG
      AND PAR_TOOL IS NOT NULL;
      IF ICOUNT2 > 0 AND TRL.TRL_TYPE NOT IN ('I') THEN
         IGLGENERATE := 0;
      END IF;
  END IF;
  
  --1.2 Verify Store 
  IF IGLGENERATE = 1 THEN
      IF TRL.TRL_STORE IS NOT NULL THEN
         SELECT COUNT(1) INTO ICOUNT FROM R5STORES 
         WHERE STR_CODE = TRL.TRL_STORE 
         AND (STR_UDFCHAR25 IS NULL OR STR_UDFCHAR26 IS NULL);
         
         SELECT COUNT(1) INTO ICOUNT2 -->0 IS ISSUE TOOL
         FROM R5PARTS 
         WHERE PAR_CODE = TRL.TRL_PART AND PAR_ORG = TRL.TRL_PART_ORG
         AND PAR_TOOL IS NOT NULL AND TRL.TRL_TYPE ='I';
         
         --Not generate GL if store no profit center/cost center and is not tool transaction
         IF ICOUNT > 0 AND ICOUNT2 = 0 THEN  
            IGLGENERATE := 0;
         END IF;
      END IF;
  END IF;
  
  --ADD BY CXU ON 20210603
  IF IGLGENERATE = 1 THEN
     IF TRL.TRL_PART IS NOT NULL THEN
        SELECT PAR_CLASS,nvl(PAR_UDFCHAR23,'51120000') INTO vParClass,vMappingGL
        FROM R5PARTS
        WHERE PAR_CODE = TRL.TRL_PART AND PAR_ORG = TRL.TRL_PART_ORG;
        IF vParClass IN ('FUEL','ADBLUE') THEN
           IGLGENERATE := 0;
        END IF;
     END IF;
  END IF;
  
  IF IGLGENERATE = 1 THEN  --1

    --Work order issue part TRL-ISSUE
    IF TRL.TRL_RTYPE = 'I' AND TRL.TRL_EVENT IS NOT NULL THEN --1.1
       -- COMPANY CODE
       SELECT SUBSTR(EVT_COSTCODE, 1, INSTR(EVT_COSTCODE, '-') - 1),EVT_COSTCODE
       INTO IWOCOMPANYCODE, IWBS
       FROM R5EVENTS
       WHERE EVT_CODE = TRL.TRL_EVENT;
       IF TRL.TRL_UDFCHAR24 IS NULL THEN
          -- ISSUE PART
          SELECT SUBSTR(STR.STR_UDFCHAR26,1,INSTR(STR.STR_UDFCHAR26, '-') - 1),STR.STR_UDFCHAR26
          INTO ISTRCOMPANYCODE, IPROFITCENTER
          FROM R5STORES STR
          WHERE STR.STR_CODE = TRL.TRL_STORE;
       ELSE
          -- ISSUE TOOLS
          IPARCOMPANYCODE := SUBSTR(TRL.TRL_UDFCHAR24,1,INSTR(TRL.TRL_UDFCHAR24, '-') - 1);                  
       END IF;

       IF NVL(TRL.TRL_ORIGQTY,TRL.TRL_QTY) > 0 THEN --1.1.1
          /*BEGIN
            SELECT EVT.EVT_COSTCODE
              INTO IWBS
              FROM R5EVENTS EVT
             WHERE EVT_CODE = :NEW.TRL_EVENT;
          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              NULL; -- PLease note, need consider how to control if no SAP information for the employee
          END;*/
          IPROFITCENTER := NULL;
          --IGLCODE       := '51120000';
          select nvl(org_udfchar05,'51120000') into IGLCODE
          from   r5organization
          where  org_code = IORGCODE;
          IF TRL.TRL_UDFCHAR24 IS NULL THEN
            IF IWOCOMPANYCODE <> ISTRCOMPANYCODE THEN
              IUSRATTR3 := IWOCOMPANYCODE;
              IUSRATTR4 := ISTRCOMPANYCODE;
            ELSE
              IUSRATTR3 := IWOCOMPANYCODE;--NULL;
              IUSRATTR4 := ISTRCOMPANYCODE;
            END IF;
          ELSE --FOR TOOL
            -- modified by cxu on Aug-2021 to get tool issue GL from PAR_UDFCHAR23 for Tool/miscellaneous activities
            IGLCODE     := vMappingGL;
            IF IWOCOMPANYCODE <> IPARCOMPANYCODE THEN
              IUSRATTR3 := IWOCOMPANYCODE;
              IUSRATTR4 := IPARCOMPANYCODE;
            ELSE
              IUSRATTR3 := IWOCOMPANYCODE;--NULL;
              IUSRATTR4 := IPARCOMPANYCODE;
            END IF;
          END IF;
       ELSE --1.1.1
          --Work order issue Tools TRL-ISSTOOLS
          BEGIN
            IF TRL.TRL_UDFCHAR24 IS NULL THEN
              -- RETURN PARTS
              /* SELECT STR_UDFCHAR26
               INTO IPROFITCENTER
               FROM R5STORES STR
              WHERE STR.STR_CODE = :NEW.TRL_STORE;*/
              IWBS    := NULL;
              IGLCODE := '16219010';
              IF IWOCOMPANYCODE <> ISTRCOMPANYCODE THEN
                IUSRATTR3 := ISTRCOMPANYCODE;
                IUSRATTR4 := IWOCOMPANYCODE;
              ELSE
                IUSRATTR3 := ISTRCOMPANYCODE;--NULL;
                IUSRATTR4 := IWOCOMPANYCODE;
              END IF;
            ELSE
              IWBS          := TRL.TRL_UDFCHAR24;
              IPROFITCENTER := NULL;
              -- modified by cxu on Aug-2021 to get tool issue GL from PAR_UDFCHAR23 for Tool/miscellaneous activities
              IGLCODE       := vMappingGL;
              --IGLCODE       := '51120000';
              IF IWOCOMPANYCODE <> IPARCOMPANYCODE THEN
                IUSRATTR3 := IPARCOMPANYCODE;
                IUSRATTR4 := IWOCOMPANYCODE;
              ELSE
                IUSRATTR3 := IPARCOMPANYCODE;--NULL;
                IUSRATTR4 := IWOCOMPANYCODE;
              END IF;
            END IF;
          EXCEPTION WHEN NO_DATA_FOUND THEN
              NULL; -- PLease note, need consider how to control if no SAP information for the employee
          END;
      END IF; --1.1.1

     ELSIF TRL.TRL_RTYPE = 'STTK' THEN  --1.2
        BEGIN
          SELECT SUBSTR(STR_UDFCHAR26, 1, INSTR(STR_UDFCHAR26, '-') - 1)
          INTO IUSRATTR4
          FROM R5STORES
          WHERE STR_CODE = TRL.TRL_STORE;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
        END;

        IF TRL.TRL_QTY < 0 THEN
          -- STTK GAIN
          BEGIN
              SELECT STR_UDFCHAR26
              INTO IPROFITCENTER
              FROM R5STORES STR
              WHERE STR.STR_CODE = TRL.TRL_STORE;
          EXCEPTION WHEN NO_DATA_FOUND THEN
              NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
          END;
          IGLCODE := '16219010';
        ELSE
          BEGIN
              SELECT STR_UDFCHAR25
              INTO ICOSTCENTER
               FROM R5STORES STR
              WHERE STR.STR_CODE = TRL.TRL_STORE;
          EXCEPTION WHEN NO_DATA_FOUND THEN
              NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
          END;
          IGLCODE := '51013000';
        END IF;
    ELSIF TRL.TRL_RTYPE = 'CORR' THEN  --1.3
      BEGIN
          SELECT SUBSTR(STR_UDFCHAR26, 1, INSTR(STR_UDFCHAR26, '-') - 1)
          INTO IUSRATTR4
          FROM R5STORES
         WHERE STR_CODE = TRL.TRL_STORE;
      EXCEPTION WHEN NO_DATA_FOUND THEN
          NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
      END;

      IF TRL.TRL_PRICE > 0 THEN
        -- CORR INCREASE
        BEGIN
            SELECT STR_UDFCHAR26
            INTO IPROFITCENTER
            FROM R5STORES STR
            WHERE STR.STR_CODE = TRL.TRL_STORE;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
        END;
        IGLCODE := '16219010';
      ELSE
        BEGIN
            SELECT STR_UDFCHAR25
            INTO ICOSTCENTER
            FROM R5STORES STR
            WHERE STR.STR_CODE = TRL.TRL_STORE;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
        END;
        IGLCODE := '51013000';
      END IF;

    ELSIF TRL.TRL_RTYPE = 'RECV' THEN --1.4
      IF TRL.TRL_EVENT IS NULL AND TRL.TRL_ORDER IS NULL THEN
        -- Stor Receiving
        BEGIN
            SELECT STR_UDFCHAR26,SUBSTR(STR.STR_UDFCHAR26, 1,INSTR(STR.STR_UDFCHAR26, '-') - 1)
            INTO IPROFITCENTER, ISTRCOMPANYCODE
            FROM R5STORES STR
           WHERE STR.STR_CODE = TRL.TRL_STORE;
        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
        END;
        IGLCODE   := '16219010';
        -- modified by Jacky on Oct-07 per the bugs fro JL and Suggestiob from CX
        -- IUSRATTR3 := ISTRCOMPANYCODE;
        -- IUSRATTR4 := NULL;
        IUSRATTR3 := NULL;
        IUSRATTR4 := ISTRCOMPANYCODE;
      ELSIF TRL.TRL_EVENT IS NOT NULL AND TRL.TRL_ORDER IS NOT NULL THEN
        -- Direct Purchase
        BEGIN
          SELECT EVT.EVT_COSTCODE,SUBSTR(EVT.EVT_COSTCODE,1,INSTR(EVT.EVT_COSTCODE, '-') - 1)         
          INTO IWBS, IWOCOMPANYCODE
          FROM R5EVENTS EVT
          WHERE EVT_CODE = TRL.TRL_EVENT;

          SELECT SUBSTR(STR.STR_UDFCHAR26,1,INSTR(STR.STR_UDFCHAR26, '-') - 1)     
          INTO ISTRCOMPANYCODE
          FROM R5STORES STR
          WHERE STR.STR_CODE = TRL.TRL_STORE;

          IF IWOCOMPANYCODE <> ISTRCOMPANYCODE THEN
            -- CROSS COMPANY
            IUSRATTR3 := IWOCOMPANYCODE;
            IUSRATTR4 := ISTRCOMPANYCODE;
          ELSE
            IUSRATTR3 := IWOCOMPANYCODE;--NULL;
            IUSRATTR4 := ISTRCOMPANYCODE;
          END IF;

        EXCEPTION WHEN NO_DATA_FOUND THEN
            NULL; -- PLease note, need consider how to control if no SAP information for the employee
        END;
        IGLCODE := '51120000';
      END IF;
    ELSIF TRL.TRL_RTYPE = 'I' AND TRL.TRL_EVENT IS NULL THEN  --1.4
      BEGIN
        /*SELECT STR_UDFCHAR25
         INTO ICOSTCENTER
         FROM R5STORES STR
        WHERE STR.STR_CODE = :NEW.TRL_STORE;*/
        --IPROFITCENTER := 'H710292500'; -- BASED ON THE NEW CHART CODE ON SEP-09
        SELECT SUBSTR(STR.STR_UDFCHAR26, 1,INSTR(STR.STR_UDFCHAR26, '-') - 1),       
               DECODE(ORG_CURR,'AUD','DFLT-PRO-H710292500','NZD','DFLT-PRO-H719288000','DFLT-PRO-H710292500')
        INTO ISTRCOMPANYCODE,IPROFITCENTER
        FROM R5STORES STR,R5ORGANIZATION ORG
        WHERE STR.STR_ORG = ORG.ORG_CODE
        AND  STR.STR_CODE = TRL.TRL_STORE;
        IUSRATTR3 := NULL;
        IUSRATTR4 := ISTRCOMPANYCODE;

      EXCEPTION WHEN NO_DATA_FOUND THEN
          NULL; -- PLease note, need consider how to control if no SAP information for the EVENTS
      END;
      -- IGLCODE := '51011100'; -- modified by Jacky on Oct-05 for the bugs
      IGLCODE := '16119000'; -- modified by Jacky on Oct-05 for the bugs
    ELSIF TRL.TRL_RTYPE = 'RETN' AND TRL.TRL_EVENT IS NOT NULL THEN --1.5
      -- DIRECT RETN
      BEGIN
          SELECT STR_UDFCHAR26,
                 SUBSTR(STR_UDFCHAR26, 1, INSTR(STR.STR_UDFCHAR26, '-') - 1)
          INTO IPROFITCENTER, ISTRCOMPANYCODE
          FROM R5STORES STR, R5ORDERS ORD
          WHERE ORD.ORD_CODE = TRL.TRL_ORDER
          AND STR.STR_CODE = ORD.ORD_STORE;
          SELECT SUBSTR(EVT.EVT_COSTCODE, 1, INSTR(EVT.EVT_COSTCODE, '-') - 1)
          INTO IWOCOMPANYCODE
          FROM R5EVENTS EVT
          WHERE EVT_CODE = TRL.TRL_EVENT;
          IF IWOCOMPANYCODE <> ISTRCOMPANYCODE THEN
            -- CROSS COMPANY
            IUSRATTR3 := ISTRCOMPANYCODE;
            IUSRATTR4 := IWOCOMPANYCODE;
          ELSE
            IUSRATTR3 := ISTRCOMPANYCODE;--NULL;
            IUSRATTR4 := IWOCOMPANYCODE;
          END IF;
      EXCEPTION WHEN OTHERS THEN
          NULL;
      END;
      IGLCODE := '16219010';

    END IF;

    -- r5o7.o7maxseq ( ccalc =>  IACCOUNT, cecalc => 1, cetype => 'ACCOUNT', chk => ICHK ) ;
    IF IWBS IS NOT NULL THEN
      IWBS := SUBSTR(IWBS, INSTR(IWBS, '-') + 1);
    END IF;
    -- add a control if just GL generated

    IF (ICOSTCENTER IS NOT NULL) OR (IWBS IS NOT NULL) OR
       (IPROFITCENTER IS NOT NULL) THEN

      INSERT INTO R5ACCOUNTDETAIL
        (ACD_CODE,
         ACD_RENTITY,
         ACD_SEGMENT1,
         ACD_SEGMENT2,
         ACD_SEGMENT3,
         ACD_SEGMENT4,
         ACD_USRATTR1,
         ACD_USRATTR3,
         ACD_USRATTR4)
      VALUES
        (TRL.TRL_ACD,
         'TRAN',
         ICOSTCENTER,
         IWBS,
         IPROFITCENTER,
         IGLCODE,
         IORGCODE,
         IUSRATTR3,
         IUSRATTR4);
    end if;
    -- :NEW.BOO_ACD := IACCOUNT;
  END IF; --1
    
 END IF; --TRL.TRL_ROUTEREC IS NULL AND NVL(TRL.TRL_PRICE, 0) <> 0

exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSLINES/Post Insert/235' ||SQLCODE || SQLERRM);
end;
