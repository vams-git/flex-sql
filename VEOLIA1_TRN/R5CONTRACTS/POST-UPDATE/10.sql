declare 
  con             r5contracts%rowtype; 

  iErrMsg         VARCHAR2(400);
  err_val         exception;
  
begin
  select * into con from r5contracts where rowid=:rowid;
  if con.con_status ='A' then 
     if con.Con_Renew is null or con.Con_Renew < con.con_end then
        iErrMsg := 'Renewal Date must be greater or equal that End Date.';
        raise err_val;
     end if;
  end if;

  
EXCEPTION
   when err_val THEN
   RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR (  -20003,'Error in Flex r5contracts/Post Update/10/'||substr(SQLERRM, 1, 500)) ; 
end;
