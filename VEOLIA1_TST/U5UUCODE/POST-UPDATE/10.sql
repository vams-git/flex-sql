declare 
 uuc           U5UUCODE%rowtype;
    
	
 
begin
  select * into uuc from U5UUCODE where rowid=:rowid;
  if uuc.uuc_entity ='CGRP' then
     update U5CURGRP 
	 set CUG_GRPDESC = uuc.uuc_desc 
	 where CUG_GRPCODE = uuc.uuc_code;
  end if;  
 
  
exception 
  when others then 
    RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/U5UUCODE/Update/10') ; 
end;