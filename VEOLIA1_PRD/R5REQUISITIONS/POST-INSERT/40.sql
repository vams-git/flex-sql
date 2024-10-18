DECLARE
    REQ             R5REQUISITIONS%rowtype;

    err_task_1      exception;
    iErrMsg         varchar2(400); 
    iLang           r5users.usr_lang%type; 
BEGIN 
    select * into req from R5REQUISITIONS where rowid=:rowid;
  
    if REQ.REQ_FROMCODE LIKE'%-E-%' then
        raise err_task_1;
    end if; 
  
EXCEPTION
WHEN 
    err_task_1 
THEN 
    iErrMsg:='The supplier cannot be used as it is a NZ employee.';
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
END;