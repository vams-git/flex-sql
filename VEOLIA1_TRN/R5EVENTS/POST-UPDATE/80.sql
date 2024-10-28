DECLARE 
  EVT R5EVENTS%ROWTYPE;
  DB_ERROR1    EXCEPTION;
  v_FMECA      r5organization.org_udfchkbox03%type;

  iErrMsg varchar2(400); 
  iLang r5users.usr_lang%type; 
BEGIN 
  SELECT * into EVT
  FROM   R5EVENTS 
  WHERE  ROWID =:ROWID;
  
  begin
    select org_udfchkbox03 into v_FMECA
    from r5organization 
    where org_code = EVT.EVT_ORG;
  exception when no_data_found then
    v_FMECA := '-';
  end;

IF v_FMECA = '+'
   AND EVT.EVT_TYPE != 'MEC'
   AND EVT.EVT_CLASS NOT IN ('OP','PS')
   AND EVT.EVT_STATUS IN ('50SO','51SO','55CA','65RP','C')
   AND (EVT.EVT_REQM IS NULL OR EVT.EVT_CAUSE IS NULL
   OR EVT.EVT_ACTION IS NULL)
   THEN 
    begin
      select usr_lang into iLang from r5users where usr_code = o7sess.cur_user; 
    exception when no_data_found then
      iLang :='EN';
    end;
     RAISE DB_ERROR1;
END IF;

EXCEPTION

WHEN DB_ERROR1 THEN 
select decode ( iLang , 'JP', 'This WO class needs Problem Code/Cause Code/Action Code. Please enter those Codes.', 'KO', '이 작업지시종류는 문제코드/원인코드/조치코드를 입력하여야 합니다.', 'ZH', '这个工单类别必须填写 [问题代码/原因代码/操作代码]。请输入所需代码。', 'This WO class needs Problem Code/Cause Code/Action Code. Please enter those Codes.' )  into iErrMsg from dual; 
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 

END;