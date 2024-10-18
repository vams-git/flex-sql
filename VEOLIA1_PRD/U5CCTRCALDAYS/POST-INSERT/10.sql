declare 
  cgd                u5cctrcaldays%rowtype;
  cgdcode            u5cctrcaldays.cgd_code%type;
  vWeekOfDay         varchar2(4);
  vWeekDay           u5cctrcaldays.cgd_weekday%type;
  
  iErrMsg            varchar2(400); 
  DB_ERROR           EXCEPTION;
begin
  select * into cgd from u5cctrcaldays where rowid=:rowid;
  
  vWeekOfDay := to_char(cgd.cgd_date,'D');
  if vWeekOfDay = '1' then
     vWeekDay :='Sun';
  elsif vWeekOfDay = '2' then
     vWeekDay :='Mon';
  elsif vWeekOfDay = '3' then
     vWeekDay :='Tues';
  elsif vWeekOfDay = '4' then
     vWeekDay :='Wed';
  elsif vWeekOfDay = '5' then
     vWeekDay :='Thurs';
  elsif vWeekOfDay = '6' then
     vWeekDay :='Fri';
  elsif vWeekOfDay = '7' then
     vWeekDay :='Sat';
  end if;
  if nvl(cgd.cgd_weekday,' ') <> nvl(vWeekDay,' ') then
      update u5cctrcaldays
      set cgd_weekday = vWeekDay
      where rowid = :rowid;
  end if;
   

exception 
WHEN DB_ERROR THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex u5cctrcaldays/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;