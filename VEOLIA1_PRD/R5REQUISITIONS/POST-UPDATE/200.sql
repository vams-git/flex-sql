declare 
 req              r5requisitions%rowtype;
 chk              VARCHAR2(3);
 vCount           number;  
 vCode            r5addetails.add_code%type;
 vEntity          r5addetails.add_entity%type;
 vEvtCostCode     r5events.evt_costcode%type;
 vPOCnt           number;
 vLineComment     varchar2(4000);

 CURSOR curs_svrrql(vReqCode varchar2) IS
 SELECT * FROM r5requislines
 WHERE rql_req = vReqCode
 and   rql_type LIKE 'S%';

 CURSOR curs_rql(vReqCode varchar2) IS
 SELECT * FROM r5requislines
 WHERE rql_req = vReqCode
 and  rql_status not in ('C');
 
 err_val          exception;
 iErrMsg          varchar2(500);
 
begin
  select * into req from r5requisitions where rowid=:rowid;
  update r5requislines
 set    rql_costcode = req.req_costcode
 where  rql_req = req.req_code
 and    rql_costcode is null;
 
 update r5requislines
 set    rql_deladdress = req.req_deladdress,
        rql_udfchar26 = req.req_deladdress
 where  rql_req = req.req_code
 and    rql_deladdress is null;

  /**1. 1. Validate requistion line ***/
  if req.req_status in ('01SS','04RS') then
      if nvl(req.req_fromcode,' ') = ' ' then
         iErrMsg := 'Supplier is mandatory for requisition.';
         raise err_val;
      end if;
        
      if nvl(req.req_udfchar24,' ') = ' ' then
        iErrMsg := 'Purchase Group is mandatory for requisition.';
        raise err_val;
      end if;
      
      for rec_rqlsvr in curs_svrrql(req.req_code) loop
         if nvl(rec_rqlsvr.rql_udfchar27,' ')=' '  then
           iErrMsg := 'Service Type is mandatory for requisition service Line.';
           raise err_val;
         end if;
       end loop;
       
       for rec_rql in curs_rql(req.req_code) loop
         if rec_rql.rql_event is not null then
           select evt_costcode into vEvtCostCode
           from r5events where evt_code = rec_rql.rql_event;
           if vEvtCostCode is null then
             iErrMsg := 'Cost Code is mandatory for Work Order ' || rec_rql.rql_event;
             raise err_val;
           end if;
         end if;
         if nvl(rec_rql.rql_price,0) <=0 then
           iErrMsg := 'Unit cost cannot be 0 for requisition line.';
           raise err_val;
         end if;
         if rec_rql.rql_udfchar20 is null then
           iErrMsg := 'Part/Service Type do not have valid SAP Item Code';
           raise err_val;
         end if;
         if rec_rql.rql_type in ('SF','ST') then
            vCode := rec_rql.rql_event || '#' || rec_rql.rql_act;
            vEntity := 'EVNT';
         else
            vCode := rec_rql.rql_req || '#' || rec_rql.rql_reqline;
            vEntity := 'REQL';
         end if;
         select count(1) into vCount from R5ADDETAILS
         where ADD_ENTITY = vEntity AND ADD_RENTITY = vEntity
         and   ADD_TYPE = '*' AND ADD_RTYPE = '*'
         and   ADD_CODE =  vCode;
         if  vCount = 0 then
             iErrMsg := 'Please fill in comment for requisition line ' || rec_rql.rql_reqline;
             raise err_val;
         end if;
         /***Add by Cxu 2021.01. Purchase order inbound delete activty comment if note is blank. 
         Keep WO comment in requistion line comment*****/
         if rec_rql.rql_type in ('SF','ST') then
            begin
             select 
             dbms_lob.substr(TO_CLOB(
                 R5REP.TRIMHTML(add_code,add_entity,add_type,add_lang,add_line) 
                 ),3500,1)
             into vLineComment
             from r5addetails
             where add_entity = 'EVNT'
             and add_code=  rec_rql.rql_event || '#' || rec_rql.rql_act
             and add_lang ='EN'
             and rownum <=1;
           exception when no_data_found then
             vLineComment := null;
           end;
           
           if vLineComment is not null then
               delete from r5addetails
               where add_entity = 'REQL' 
               and   add_code = rec_rql.rql_req || '#' || rec_rql.rql_reqline;
               
               insert into r5addetails
               (add_entity,add_rentity,add_type,add_rtype,add_code,
               add_lang,add_line,add_print,add_text,add_created,add_user)
               values
               ('REQL','REQL','*','*',rec_rql.rql_req || '#' || rec_rql.rql_reqline,
               'EN',10,'+',vLineComment,o7gttime(req.req_org),O7SESS.cur_user);
           end if;
           
         end if;
       end loop;
  end if;
  
  /****Copy requistion line comment back to activty ****/
  if req.req_status in ('A') then
    for rec_rql in curs_rql(req.req_code) loop
     if rec_rql.rql_type in ('SF','ST') then
        select count(1) into vCount from R5ADDETAILS
        where add_entity = 'EVNT' 
        and   add_code = rec_rql.rql_event || '#' || rec_rql.rql_act;
        if vCount = 0 then  
            begin
             select 
             dbms_lob.substr(TO_CLOB(
                 R5REP.TRIMHTML(add_code,add_entity,add_type,add_lang,add_line) 
                 ),3500,1)
             into vLineComment
             from r5addetails
             where add_entity = 'REQL'
             and add_code=  rec_rql.rql_req || '#' || rec_rql.rql_reqline
             and add_lang ='EN'
             and rownum <=1;
           exception when no_data_found then
             vLineComment := null;
           end;
               
           if vLineComment is not null then
               /*delete from r5addetails
               where add_entity = 'EVNT' 
               and   add_code = rec_rql.rql_req || '#' || rec_rql.rql_reqline;*/   
               insert into r5addetails
               (add_entity,add_rentity,add_type,add_rtype,add_code,
               add_lang,add_line,add_print,add_text,add_created,add_user)
               values
               ('EVNT','EVNT','*','*',rec_rql.rql_event || '#' || rec_rql.rql_act,
               'EN',10,'+',vLineComment,o7gttime(req.req_org),O7SESS.cur_user);
           end if;
        end if; --comment count for work order activity is 0
     end if;
    end loop;
  end if;
  
  /**2.Update Requistion Line Status***/
  if req.req_status in ('03RJ','A','CP') then
   --validate if any po assoicate, If yes do not update line status, it should be same as PO line status
   select count(1) into vPOCnt 
   from r5orderlines
   where orl_req = req.req_code;
   if vPOCnt = 0 then 
       for rec_rql in curs_rql(req.req_code) loop
           update r5requislines
           set    rql_status  = decode(req.req_status,'03RJ','C',req.req_status),
                  rql_rstatus = decode(req.req_status,'03RJ','C',req.req_rstatus),
                  rql_active = decode(req.req_status, 'A','+','03RJ','-','CP','-',rql_active)
           where  rql_req = rec_rql.rql_req and rql_reqline = rec_rql.rql_reqline
           and    rql_status <> req.req_status;
           --and    rql_status not in ('C');
       end loop;
   end if;
  end if;

  /**3.Update Requistion Line Active Status***/
  if  req.req_status in ('RC','RI') then
         update r5requislines
         set rql_active ='-'
         where  rql_req = req.req_code
         and rql_active ='+';
  end if;
exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5requisitions/Update/200') ;
end;
 