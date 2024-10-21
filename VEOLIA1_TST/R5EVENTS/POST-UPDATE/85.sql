DECLARE 
  evt          r5events%ROWTYPE;
  DB_ERROR1    EXCEPTION;
  v_FMECA      r5organization.org_udfchkbox03%type;

  iErrMsg varchar2(400); 
BEGIN 
  select  * into evt from r5events where rowid=:rowid;
  
  if evt.evt_created < to_date('2023-01-01','YYYY-MM-DD') then
     return;
  end if;
  
  /*begin
    select org_udfchkbox03 into v_FMECA
    from r5organization 
    where org_code = EVT.EVT_ORG;
  exception when no_data_found then
    v_FMECA := '-';
  end;*/
  
  IF EVT.EVT_FAILURE is NULL AND EVT.EVT_TYPE != 'MEC' AND EVT.EVT_CLASS IN ('BD','CO') AND EVT.EVT_STATUS IN ('51SO','50SO','49MF','48MR','65RP','55CA','C') 
     AND (
   (EVT.EVT_ORG IN ('BEN','BAL','GSP','ROS','GER','WYU','BAR','BGW','BTT','BRK','EPT','WCC','WCR','GCD','WOO','RRM','HWC','KUR','TTB','WLT','WEW','SPR','SBW', 'CFA','QGC','NPA','CGC','SPF'))
   OR 
   (EVT.EVT_ORG = 'KIL' AND EVT.EVT_MRC IN ('KIL-DCT-OP','KIL-MT','KIL-CO','KIL-KLP-OP'))
   )
  THEN
      iErrMsg :=  'This WO class needs a Failure Code. Please enter a code.';
      RAISE DB_ERROR1;
  END IF;
/*
IF EVT.EVT_ORG IN ('BEN','BAL','GSP','ROS','GER','WYU','BAR','BGW','BTT','EPT','WCC','WCR','GCD','WOO','RRM','HWC','KUR','TTB','WLT','WEW','SPR','SBW', 'CFA','QGC','NPA','CGC','SPF')
   AND EVT.EVT_TYPE != 'MEC'
   AND EVT.EVT_CLASS IN ('BD','CO')
   AND EVT.EVT_STATUS IN ('51SO','50SO','49MF','48MR','65RP','55CA','C')
   AND (EVT.EVT_FAILURE is NULL)
   THEN RAISE DB_ERROR1;
END IF;
*/



EXCEPTION WHEN DB_ERROR1 THEN 
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
END;