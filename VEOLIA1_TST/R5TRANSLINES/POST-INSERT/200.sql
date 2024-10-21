declare 
 trl            r5translines%rowtype;
 vIssuePrice    r5translines.trl_price%type;
 iMsg           varchar2(500);
 test_err       exception;
begin
  select * into trl from r5translines where rowid=:rowid;
  
  --return part from work order to store
  if trl.trl_type = 'I' and nvl(trl.trl_origqty,trl.trl_qty)  < 0 and trl.trl_event is not null then
 
       
     begin  
         select trl_price into vIssuePrice from
          (select trl_price
          from r5translines
          where trl_type ='I'
          and trl_event = trl.trl_event and trl_act = trl.trl_act 
          and trl_part = trl.trl_part and trl_part_org = trl.trl_part_org
          and trl_store = trl.trl_store --bin/leot
          and nvl(trl_origqty,trl_qty) > 0
          order by trl_trans desc
          )where rownum <= 1;
          
          --iMsg := 'Issue Price:' ||  vIssuePrice;
          --RAISE test_err;
          
          if vIssuePrice <> trl.trl_price then
             update r5translines
             set trl_price = vIssuePrice
             where trl_trans = trl.trl_trans and trl_line = trl.trl_line
             and trl_price <> vIssuePrice;
          end if;
     exception when no_data_found then
       iMsg := 'No data found for recv';
       RAISE test_err;
     end;
  end if;
  
exception
when test_err then
RAISE_APPLICATION_ERROR (-20001,iMsg) ; 
--when others then
--RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5translines/Post Insert/200') ;  
end;