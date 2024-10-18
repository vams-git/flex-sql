declare 
 req              r5requisitions%rowtype;
 chk              VARCHAR2(3);
 vCount           number;         


 CURSOR curs_rql(vReqCode varchar2) IS
 SELECT * FROM r5requislines
 WHERE rql_req = vReqCode;
 
 err_val          exception;
 iErrMsg          varchar2(500);
 
 /*cursor cur_doc is
 select *
 from r5docentities 
 where dae_entity ='REQ' and dae_code = vReqCode;*/
 
begin
  select * into req from r5requisitions where rowid=:rowid;
   /**3.Delete work order doccument if req line is deleted*/
  if req.req_status IN  ('01SS') then
     delete from r5docentities dae_req
     where dae_entity ='REQ' and dae_code = req.req_code
     and   exists 
     (select 1 from r5docentities dae_evt 
     where dae_evt.dae_entity ='EVNT' and dae_evt.dae_document = dae_req.dae_document 
     and dae_evt.dae_code not in (select rql_event from r5requislines
     where rql_req = req.req_code)
     );
  end if;
  
  /**3.Delete duplicate comments on requistion lines***/
  if req.req_status IN  ('01SS','03RJ','04RS','A','C') then
    for rec_rql in curs_rql(req.req_code) loop
        select count(1) into vCount
        from   r5addetails
        where  add_entity = 'REQL' and ADD_TYPE = '*'
        and    ADD_CODE like rec_rql.Rql_Req || '#' || rec_rql.rql_reqline;
        if vCount > 1 then
             delete from r5addetails where add_line
             not in (select min(add_line) from r5addetails
             where  add_entity = 'REQL' and add_type = '*'
             and    add_code LIKE rec_rql.Rql_Req || '#' || rec_rql.rql_reqline
             group by add_entity,add_type,add_code,add_lang
             )
             and add_entity = 'REQL' and ADD_TYPE = '*'
             and  ADD_CODE like rec_rql.Rql_Req || '#' || rec_rql.rql_reqline;
        end if;
        update r5addetails
        set add_line = 10
        where add_entity = 'REQL' and add_type = '*'
        AND   add_code LIKE rec_rql.Rql_Req || '#' || rec_rql.rql_reqline
        and   add_line <> 10;

     end loop;
   end if;
  
exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Update/210') ;
end;
