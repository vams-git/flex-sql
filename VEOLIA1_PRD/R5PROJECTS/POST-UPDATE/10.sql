DECLARE 
  PRJ           R5PROJECTS%ROWTYPE;
  DB_ERROR1     EXCEPTION;
  vSumBudget    r5projbudclasses.pcl_amount%type;
  iErrMsg       varchar(400);
  iLang         r5users.usr_lang%type;

BEGIN 
  SELECT * INTO PRJ
  FROM R5PROJECTS
  WHERE  ROWID =:ROWID;
  
  if prj.prj_status = 'O' then
    select nvl(sum(pcl_amount),0) into vSumBudget
    from   r5projbudclasses where pcl_project = prj.prj_code;
    if vSumBudget = 0 then
      begin
      select usr_lang into iLang from r5users where usr_code = o7sess.cur_user;
      exception when no_data_found then iLang := 'EN'; end;
      RAISE DB_ERROR1;
    end if;
  end if;

EXCEPTION
WHEN DB_ERROR1 THEN 
 iErrMsg := 'The project cannot be approved, because current budget is 0. Please enter dollar value on budget tab';
 RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
WHEN OTHERS THEN
  NULL;
END;