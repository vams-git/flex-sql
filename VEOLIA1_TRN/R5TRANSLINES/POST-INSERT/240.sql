declare 
  vCnt      number;
  iErrMsg   varchar2(200);
  val_err   exception;
  
begin
  SELECT count(1) into vCnt
  FROM R5EVENTS EVT,R5TRANSLINES TRL,R5ORGANIZATION ORG,R5STORES STR
  WHERE EVT.EVT_ORG = ORG.ORG_CODE
  AND   EVT.EVT_CODE = TRL.TRL_EVENT
  AND   TRL.TRL_STORE = STR.STR_CODE
  AND   TRL.TRL_RTYPE IN ('I')
  AND   ORG.ORG_UDFCHAR09 IS NOT NULL
  AND   STR.STR_UDFCHAR26 IS NOT NULL
  AND   EVT.EVT_COSTCODE IS NULL
  AND   TRL.ROWID =:ROWID;
  
  if vCnt > 0 then
     iErrMsg := 'Can not issue part due to the Work Order Cost Code is blank.';
     raise val_err;
  end if;
  
  SELECT count(1) into vCnt
  FROM R5EVENTS EVT,R5TRANSLINES TRL,R5ORGANIZATION ORG,R5STORES STR,R5PARTS
  WHERE EVT.EVT_ORG = ORG.ORG_CODE
  AND   EVT.EVT_CODE = TRL.TRL_EVENT
  AND   TRL.TRL_STORE = STR.STR_CODE
  AND   TRL.TRL_PART = PAR_CODE AND TRL.TRL_PART_ORG = PAR_ORG AND PAR_TOOL IS NOT NULL 
  AND   TRL.TRL_RTYPE IN ('I')
  AND   ORG.ORG_UDFCHAR09 IS NOT NULL
  AND   STR.STR_UDFCHAR26 IS NOT NULL
  AND   PAR_UDFCHAR23 IS NULL 
  AND   TRL.ROWID =:ROWID;
  
  if vCnt > 0 then
     iErrMsg := 'Can not issue part due to the Mapping Part GL is blank.';
     raise val_err;
  end if;
  
exception when val_err then
  RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;   
end;