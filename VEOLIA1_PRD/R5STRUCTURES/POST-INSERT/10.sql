declare
   stc           r5structures%rowtype;
   sorg         number;

begin
    select * into stc from r5structures where rowid=:rowid;

    select count(1) into sorg from r5organization
    where org_code = stc.stc_child_org
       and org_udfchar10 like '%Fleet%';

    if stc.stc_childtype in ('02ET', '03UT' ) 
       and nvl(stc.stc_rolldown,'-') = '-' and sorg = 0 then
       update r5structures
       set stc_rolldown = '+'
       where rowid =:rowid;
    end if;

    if stc.stc_childtype in ('04AS', '05FP','06EQ','07CP' ) and nvl(stc.stc_rolldown,'-') = '-' then
       update r5structures
       set stc_rolldown = '+'
       where rowid =:rowid;
    end if;
   
exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5structures/Update/10') ; 
end;