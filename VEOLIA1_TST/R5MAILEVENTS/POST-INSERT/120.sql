declare
   rec_mae        r5mailevents%rowtype;
   vCount         number;
   vConUserCnt    number;

begin
    select * into rec_mae from r5mailevents where rowid=:rowid; 
	--include document for purchase order
	if rec_mae.mae_template = 'M-ORD-APPR-ALERT' and nvl(rec_mae.mae_param11,'-') = '+' then
	   --rec_mae.mae_param2||'#'||rec_mae.mae_param10 ord_code||'#'||ord_org
	   update r5mailevents
       set    mae_docrentity = 'PORD',
	          mae_docpk = rec_mae.mae_param2||'#'||rec_mae.mae_param10
       where  mae_code = rec_mae.mae_code;
    end if;

exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5mailevents/Post Insert/120') ;
end;