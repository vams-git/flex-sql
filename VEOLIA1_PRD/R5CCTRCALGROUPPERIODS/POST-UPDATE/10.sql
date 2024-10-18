declare 
  cgp                r5cctrcalgroupperiods%rowtype;
  vStartTime         varchar2(5);
  vEndTime           varchar2(5);
  vIsNonWorkDay      varchar2(1);
  
  iErrMsg            varchar2(400); 
  DB_ERROR           EXCEPTION;
  
   cursor cur_workdate(vStartDate date,vEndDate date) is
   select vStartDate + rownum -1 as workdate,to_char(vStartDate + rownum -1,'D') as weekday
   from all_objects
   where rownum <= vEndDate-vStartDate+1;
begin
  select * into cgp from r5cctrcalgroupperiods where rowid=:rowid;
  delete from U5CCTRCALDAYS
  where cgd_grouporg = cgp.cgp_grouporg
  and   cgd_groupcode = cgp.cgp_groupcode
  and   cgd_period = cgp.cgp_period;
  
  FOR j IN cur_workdate(cgp.cgp_start, cgp.cgp_end) LOOP
     vIsNonWorkDay := '-';
     vStartTime    := null;
     vEndTime    := null;
     if j.weekday = 1 then               --sun
       if cgp.cgp_sunstart is null or cgp.cgp_sunend is null then
         vIsNonWorkDay:='+';
       else
         select to_char(trunc(mod(sum(cgp.cgp_sunstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_sunstart),60), 'FM00') into vStartTime from dual;
         select to_char(trunc(mod(sum(cgp.cgp_sunend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_sunend),60), 'FM00') into vEndTime from dual;
       end if;
     elsif j.weekday = 2 then            --mon
        if cgp.cgp_monstart is null or cgp.cgp_monend is null then
           vIsNonWorkDay:='+';
        else
          select to_char(trunc(mod(sum(cgp.cgp_monstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_monstart),60), 'FM00') into vStartTime from dual;
          select to_char(trunc(mod(sum(cgp.cgp_monend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_monend),60), 'FM00') into vEndTime from dual;
        end if;
     elsif j.weekday = 3 then            --tue
        if cgp.cgp_tuesstart is null or cgp.cgp_tuesend is null then
           vIsNonWorkDay:='+';
        else
          select to_char(trunc(mod(sum(cgp.cgp_tuesstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_tuesstart),60), 'FM00') into vStartTime from dual;
          select to_char(trunc(mod(sum(cgp.cgp_tuesend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_tuesend),60), 'FM00') into vEndTime from dual;
        end if;
     elsif j.weekday = 4 then            --wed
        if cgp.cgp_wedstart is null or cgp.cgp_wedend is null then
           vIsNonWorkDay:='+';
        else
          select to_char(trunc(mod(sum(cgp.cgp_wedstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_wedstart),60), 'FM00') into vStartTime from dual;
          select to_char(trunc(mod(sum(cgp.cgp_wedend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_wedend),60), 'FM00') into vEndTime from dual;
        end if;
     elsif j.weekday = 5 then            --thu
        if cgp.cgp_thursstart is null or cgp.cgp_thursend is null then
           vIsNonWorkDay:='+';
        else
          select to_char(trunc(mod(sum(cgp.cgp_thursstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_thursstart),60), 'FM00') into vStartTime from dual;
          select to_char(trunc(mod(sum(cgp.cgp_thursend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_thursend),60), 'FM00') into vEndTime from dual;
        end if;
     elsif j.weekday = 6 then            --fri
         if cgp.cgp_fristart is null or cgp.cgp_friend is null then
           vIsNonWorkDay:='+';
         else
           select to_char(trunc(mod(sum(cgp.cgp_fristart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_fristart),60), 'FM00') into vStartTime from dual;
           select to_char(trunc(mod(sum(cgp.cgp_friend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_friend),60), 'FM00') into vEndTime from dual;
         end if;
     elsif j.weekday = 7 then            --sat
        if cgp.cgp_satstart is null or cgp.cgp_satend is null then
           vIsNonWorkDay:='+';
        else
          select to_char(trunc(mod(sum(cgp.cgp_satstart),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_satstart),60), 'FM00') into vStartTime from dual;
          select to_char(trunc(mod(sum(cgp.cgp_satend),3600)/60), 'FM00')||':'|| to_char(mod(sum(cgp.cgp_satend),60), 'FM00') into vEndTime from dual;
        end if;
     end if;

     insert into U5CCTRCALDAYS
     (cgd_code,cgd_grouporg,cgd_groupcode,cgd_period,
      cgd_date,cgd_starttime,cgd_endtime,cgd_isnonwork,
      CREATEDBY,CREATED,UPDATECOUNT)
      values
      (s5interface.nextval,cgp.cgp_grouporg,cgp.cgp_groupcode,cgp.cgp_period,
      j.workdate,vStartTime,vEndTime,vIsNonWorkDay,
      o7sess.cur_user,o7gttime(cgp.cgp_grouporg),0);
   end loop;
   

exception 
WHEN DB_ERROR THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5cctrcalgroupperiods/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;