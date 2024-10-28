DECLARE

  evt         R5EVENTS%ROWTYPE;
  vBooHours   number;
  vTrlQty     number;
  vTouHours   number;
  iErrMsg     VARCHAR2(4000);
  vStatusDesc VARCHAR2(80);
  errorCheck  EXCEPTION;

BEGIN
  -- select the current WO 
  SELECT * INTO evt FROM R5EVENTS WHERE ROWID=:ROWID;
  IF evt.evt_type IN ('PPM','JOB') and evt.evt_status IN ('30CL','31DU') THEN
     vStatusDesc := r5o7.o7get_desc('EN','UCOD',evt.evt_status,'EVST', '');
     select sum(nvl(boo_orighours,boo_hours)) into vBooHours
     from r5bookedhours
     where boo_event = evt.evt_code;
     IF vBooHours > 0 THEN
        iErrMsg:= 'This workorder cannot move to '|| vStatusDesc || ' as there are hours or additional cost booked against it';
        RAISE errorCheck;
     END IF;
     select sum(nvl(trl_origqty,trl_qty)) into vTrlQty
     from r5translines
     where trl_event =  evt.evt_code;
     IF vTrlQty > 0 THEN
          iErrMsg:= 'This workorder cannot move to '|| vStatusDesc || ' as there are parts or additional cost booked against it';
          RAISE errorCheck;
     END IF; 
     select sum(nvl(tou_orighours,tou_hours)) into vTouHours
     from r5toolusage
     where tou_event = evt.evt_code;
     IF vTouHours > 0 THEN
          iErrMsg:= 'This workorder cannot move to '|| vStatusDesc || ' as there are tools booked against it';
          RAISE errorCheck;
     END IF; 
  END IF;  

   
  
  EXCEPTION
    WHEN errorCheck THEN
        RAISE_APPLICATION_ERROR ( -20003, iErrMsg);
      WHEN OTHERS THEN
           RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/265/'||substr(SQLERRM, 1, 500));
END;