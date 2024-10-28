declare 
  dad                r5deladdresses%rowtype;
  vOrg               varchar2(15);
  vFlag              varchar2(4);
  checkresult          varchar2(4):= '0';
  cerrsource           varchar2(15);
  cerrtype             varchar2(4);
  x                    varchar2(1);
  iErrMsg            varchar2(400); 
  DB_ERROR           EXCEPTION;
begin
  select * into dad from r5deladdresses where rowid=:rowid;
  --Inserting
  vFlag := 'UPD';
  
  if instr(dad.dad_code,'-') > 0 then
     vOrg := substr(dad.dad_code,1,INSTR(dad.dad_code,'-')-1);
     /* Insert descriptions */
      o7descs(vFlag, x, 'ADDR', x, '*', dad.dad_code, vOrg, dad.Dad_Desc, checkresult );
      IF checkresult <> '0' THEN
          cerrsource   := 'O7DESCS';
          cerrtype     := 'PROC';
          RAISE db_error;
      END IF;
  end if;

exception 
WHEN DB_ERROR THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5deladdresses/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;