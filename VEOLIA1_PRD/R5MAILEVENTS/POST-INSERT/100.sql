declare
   rec_mailevent  r5mailevents%rowtype;
   vCount         number;
   vConUserCnt    number;

begin
    select * into rec_mailevent
    from r5mailevents
    where rowid=:rowid; 
    
    select count(1) into vCount
    from r5mailtemplate mt
    where mt.mat_code = rec_mailevent.mae_template
    and   mt.mat_report is not null;
    
    if vCount > 0 then
      if rec_mailevent.mae_param15 is null then
         update r5mailevents
         set  mae_param15 = 'R5'
         where mae_code = rec_mailevent.mae_code
         and   mae_param15 is null;
       else
         select count(1) into vConUserCnt
         from r5users usr
         where upper(usr_code) = upper(rec_mailevent.mae_param15) 
         and   nvl(usr.usr_consumer,'-')= '+';
         if vConUserCnt = 0 then
            update r5mailevents
            set  mae_param15 = 'R5'
            where mae_code = rec_mailevent.mae_code;
         end if;  
      end if;
    end if;

  
    if instr(rec_mailevent.mae_emailrecipient,'@') = 0 then
       update r5mailevents
       set mae_rstatus = 'E',mae_send ='-',mae_error = 'No Email Recipients',mae_emailerrcount = 4
       where mae_code = rec_mailevent.mae_code
       and   mae_error is null;
    end if;
      
    
exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5mailevents/Post Insert/100') ;
end;