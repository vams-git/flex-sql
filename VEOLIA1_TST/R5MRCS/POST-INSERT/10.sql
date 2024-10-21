declare 
  mrc               r5mrcs%rowtype;
  vPos              number;
  
  iErrMsg           varchar2(400);
  err_val           exception;
begin
  select * into mrc from r5mrcs where rowid=:rowid;
  
  vPos := INSTR(mrc.mrc_code,'-');
  if (vPos>0) then
     if substr(mrc.MRC_CODE,1,vPos-1)<>mrc.mrc_org then
        iErrMsg := 'The Code should begin with <Organization>+<->';
        raise err_val;
     end if;
  else
        iErrMsg:= 'The Code should begin with <Organization>+<->';
        raise err_val;
  end if;

exception 
WHEN err_val THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5mrcs/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;