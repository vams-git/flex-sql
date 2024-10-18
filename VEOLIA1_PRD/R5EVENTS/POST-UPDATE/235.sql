declare 
  evt               r5events%rowtype; 
  iErrMsg           varchar2(4000);
  err_chk           exception;
  vCount            number;

  vLine             r5addetails.add_line%type;
  
  vNewStatus        r5events.evt_status%type;
  vOldStatus        r5events.evt_status%type;
  vTimeDiff         number;
  
  vOpaValue         r5organizationoptions.opa_desc%type;
  
  cursor curs_child(cEvent varchar2) IS
  select evt_code from r5events where evt_parent = cEvent;
  
  cursor curs_child_comment(cEvent varchar2) IS
  select add_code,add_line
  from r5addetails
  where add_code = cEvent
  and   R5REP.TRIMHTML(add_code,add_entity,add_type,'EN',add_line) 
  --U7GETADDETAILS(add_entity,add_type,add_code,add_line)
  like '- From parent WO.%';
  
  cursor curs_comment(cEvent varchar2) IS
  select *
  from r5addetails where add_entity='EVNT' and add_code = cEvent 
  order by add_line;
begin
   --Convert from  U5POSUPD_EVT_COMMENT to copy parent WO Comment/Value to Child WO
  select * into evt from r5events where rowid=:rowid;
  if evt.evt_type in ('JOB','PPM') then
    IF evt.evt_parent is null THEN
      --Check is parent WO status change?
       begin
          select ava_to,ava_from,timediff into vNewStatus,vOldStatus,vTimeDiff
           from (
          select ava_to,ava_from,abs(sysdate - ava_changed) * 24 * 60 * 60 as timediff
          from r5audvalues,r5audattribs
          where ava_table = aat_table and ava_attribute = aat_code
          and   aat_table = 'R5EVENTS' and aat_column = 'EVT_STATUS'
          and   ava_table = 'R5EVENTS' 
          and   ava_primaryid = evt.evt_code
          and   ava_updated = '+'
          and   abs(sysdate - ava_changed) * 24 * 60 * 60 < 2
          order by ava_changed desc
          ) where rownum <= 1;
       exception when no_data_found then 
          vNewStatus := null;
          return;
       end;
       
        --copy fmea,status code etc to children wo
        for rec_child in curs_child(evt.evt_code) loop
            update r5events
            set    evt_status     = evt.evt_status,
                   evt_rstatus    = evt.evt_rstatus,
                   evt_desc       = evt.evt_desc,
                   evt_mrc        = evt.evt_mrc,
                   evt_class      = evt.evt_class,
                   evt_class_org  = evt.evt_class_org,
                   evt_target     = evt.evt_target,
                   evt_schedend   = evt.evt_schedend,
                   evt_requeststart= evt.evt_requeststart,
                   evt_requestend = evt.evt_requestend,
                   evt_person     = evt.evt_person,
                   evt_completed  = evt.evt_completed,
                   evt_ppm        = evt.evt_ppm,
                   evt_ppmrev     = evt.evt_ppmrev,
                   evt_reqm       = evt.evt_reqm,
                   evt_cause      = evt.evt_cause,
                   evt_action     = evt.evt_action,
                   evt_failure    = evt.evt_failure,
                   evt_udfchar29  = evt.evt_udfchar29,
                   evt_udfchkbox05 = evt.evt_udfchkbox05,
                   evt_costcode    = evt.evt_costcode,
                   evt_udfchar20   = evt.evt_udfchar20,
                   evt_udfchar24   = evt.evt_udfchar24,
                   evt_udfdate03   = evt.evt_udfdate03
             where evt_code = rec_child.evt_code;
      end loop;

     
      IF evt.evt_status IN ('C') THEN
         --REMOVE MATERIAL LIST --COMMENT ON 30-DEC-2021 BY CXU
         select count(1) into vCount
         from r5activities act where act.act_event = evt.evt_code and act.act_matlist like 'V-%';
         if vCount > 0 then
           update r5activities act
           set    act.act_matlist = null,act.act_matlrev = null
           where act.act_event = evt.evt_code and act.act_matlist like 'V-%';
         end if;
         
         for rec_child in curs_child(evt.evt_code) loop
             --delete comments which copy from parent WO
            for rec_child_comment in curs_child_comment(rec_child.evt_code) loop
              delete from r5addetails
              where add_entity ='EVNT' and add_code = rec_child.evt_code
              and   add_line = rec_child_comment.add_line;
            end loop;
            --loop parent work order comments
            for rec_comment in curs_comment(evt.evt_code) loop
               --get max line for child work order comment
               begin
                 select nvl(max(add_line),0) + 10
                 into   vLine
                 from   r5addetails
                 where  add_entity='EVNT' and add_code = rec_child.evt_code;
               exception when no_data_found then
                 vLine := 10;
               end;
               
               insert into r5addetails
               (add_entity,add_rentity,add_type,add_rtype,add_code,
               add_lang,add_line,add_print,add_text,add_created,add_user)
               values
               (rec_comment.add_entity,rec_comment.Add_Rentity,rec_comment.Add_Type,rec_comment.Add_Rtype,
               rec_child.evt_code,rec_comment.add_lang,vLine,rec_comment.Add_Print,
               dbms_lob.substr(TO_CLOB('- From parent WO. ')
               || TO_CLOB(
               R5REP.TRIMHTML(rec_comment.add_code,rec_comment.add_entity,rec_comment.add_type,rec_comment.add_lang,rec_comment.add_line) 
               ),4000,1),
               --rec_addline.Add_Text,
               o7gttime(evt.evt_org),rec_comment.add_user);
            end loop;
            
         end loop;
      END IF; --evt.evt_status IN ('C')
      
      -- For all orgs without exception, when a WO status is chnaged to 30CL, comments must be entered
      IF evt.evt_status in ('30CL') THEN
         select count(1) into vCount
         from r5addetails
         where add_entity='EVNT' and add_code = evt.evt_code;
         if (nvl(vCount,0) =0) then
           iErrMsg:='Please note WO Comments is mandatory data for this WO to be '|| r5o7.o7get_desc('EN','UCOD',evt.evt_status,'EVST', '')
            ||'. please fill the appropriate fields and try again.';
            raise err_chk;
         end if;
      END IF; --evt.evt_status in ('30CL')
      
      --For selected orgs, Comments is mandatory when status changed to 50SO, 51SO
      IF evt.evt_status in ('50SO', '51SO') THEN
         begin
            select opa_desc into vOpaValue
            from r5organizationoptions WHERE OPA_CODE='WCLOVALD' AND OPA_ORG =evt.evt_org;
         exception when no_data_found then
            vOpaValue :='NO';
         end;
         if vOpaValue in ('COMM','BOTH') then
            select count(1) into vCount
            from r5addetails
            where add_entity='EVNT' and add_code = evt.evt_code;
            if (nvl(vCount,0) =0) then
              iErrMsg:='Please note WO Comments is mandatory data for this WO to be '|| r5o7.o7get_desc('EN','UCOD',evt.evt_status,'EVST', '')
               ||'. please fill the appropriate fields and try again.';
              raise err_chk;
            end if;
         end if;
      END IF; --evt.evt_status in ('50SO', '51SO')
      
      --Check Organization option WCLOCOMM ((VAMS) WO validation for Closing When it is set to YES, closing comment is mandatory when WO status change to 50SO, 51SO, 49MF, 48MR
      IF evt.evt_status in ('50SO','51SO','49MF','48MR','53MH') THEN
        begin
          select opa_desc into vOpaValue
          from r5organizationoptions WHERE OPA_CODE='WCLOCOMM' AND OPA_ORG =evt.evt_org;
        exception when no_data_found then
           vOpaValue :='NO';
        end;

        if vOpaValue not in ('NO') then
           select count(1) into vCount
           from r5addetails
           where add_entity='EVNT' and add_code = evt.evt_code
           and   add_type = '+';

           if (nvl(vCount,0) =0) then
              iErrMsg:='Please note WO Closing Comments is mandatory data for this WO to be ' || r5o7.o7get_desc('EN','UCOD',evt.evt_status,'EVST', '')
              ||'. please fill the appropriate fields and try again.';
              raise err_chk;
           end if;
        end IF;
      END IF;-- evt.evt_status in ('50SO','51SO','49MF','48MR','53MH')
      
    END IF; --evt.evt_parent is null
  end if; --evt.evt_type in ('JOB','PPM')
  
EXCEPTION
  WHEN err_chk THEN
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
   when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,'Error in Flex R5EVENTS/Post Update/235/'||substr(SQLERRM, 1, 500)) ;
end;