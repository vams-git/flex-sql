declare 
  ock             r5operatorchecklists%rowtype;
  vMat            r5mailevents.mae_code%type;
  vTskClass       r5classes.cls_code%type;
  vSessionDesc    r5actchecklists.ack_notes%type;
  vObjCond        r5objects.obj_udfchar21%type;
  vObjNextAccDate r5objects.obj_udfdate01%type;
  vObjAssessReq   r5objects.obj_udfchkbox01%type;
  vObjCrit        r5objects.obj_criticality%type;
  vObjRisk        r5objects.obj_udfnum02%type;
  vObjPosC        r5objects.obj_udfchar16%type;
  vObjSafe        r5objects.obj_safety%type;
  vObjRepV        r5objects.obj_replacementvalue%type;
  vObjBuiY        r5objects.obj_yearbuilt%type;
  vObjMode        r5objects.obj_manufactmodel%type;
  vObjModN        r5objects.obj_udfchar30%type;
  vObjSerN        r5objects.obj_serialno%type;
  vObjMatT        r5objects.obj_udfchar32%type;
  vObjSize        r5objects.obj_udfchar33%type;
  vObjSizeUom     r5objects.obj_udfchar18%type;
  vObjSpec        r5objects.obj_udfchar34%type;
  vDocClass       r5classes.cls_code%type;
  vCount          number;
  v_110Notes      r5actchecklists.ack_notes%type;
  v_120Notes      r5actchecklists.ack_notes%type;
  vCondDoc        number;
  iErrMsg         varchar2(200);
  err             exception;
  
  cursor cur_opdoc(vOpCode varchar2,vOrg varchar2) is 
  select ack.ack_code,dae.dae_document,ack.ack_sequence,ack.ack_finding,ack.ack_yes,ack_completed
  from  r5docentities dae,r5actchecklists ack
  where ack_code = dae_code
  and   dae_entity = 'OPCL'  
  and   ack_rentity = 'OPCK' and ack_entitykey = vOpCode and ack_entityorg = vOrg
  and   ack_sequence in (131,135,250);
 
begin
  select * into ock from r5operatorchecklists where rowid=:rowid; --ock_code = '10020';
  if ock.ock_rstatus in ('U','CC') then
    return;
  end if;
  select tsk_class into vTskClass
  from r5tasks where tsk_code = ock.ock_task and tsk_revision = ock.ock_taskrev;
  if vTskClass ='CONA' then
    select substr(ack_notes,1,80) into vSessionDesc
    from r5actchecklists
    where   ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
    and   ack_sequence in (100);
    if ock.ock_status = 'R'then--ock.ock_task = 'CAUS-T-0001'  
       begin
         select mat_code into vMat  
         from r5mailtemplate 
         where mat_code = 'M-OPER-REVIEW-' || ock.ock_org;
       exception when no_data_found then
         vMat := 'M-OPER-REVIEW';
       end;
       
       insert into r5mailevents(
       mae_template,mae_date,mae_send,mae_rstatus,mae_attribpk,mae_emailrecipient,--mae_param15,
       mae_param1,mae_param2,mae_param3,mae_param4,mae_param5,mae_param6
       )
       values(
       vMat,SYSDATE,'-','N',0,null,
       null,ock.ock_object,r5o7.o7get_desc('EN', 'OBJ',ock.ock_object || '#' || ock.ock_object_org, '', ''),
       ock.ock_code,vSessionDesc,to_char(ock.ock_startdate,'DD-MON-YYYY'));
    end if;
    if ock.ock_status = 'C'then--ock.ock_task = 'CAUS-T-0001'  
    --110 condition
    --- When checklist sequence 110 is answered and validated, the plan is to edit the field OBJ_UDFCHAR21 with the following mapping
    begin
     select 
     case when ack_finding = 'CON1' then '1'
     when ack_finding = 'CON2' then '2'
     when ack_finding = 'CON3' then '3'
     when ack_finding = 'CON4' then '4'
     when ack_finding = 'CON5' then '5'
     end, ack_notes
     into vObjCond,v_110Notes
     from r5actchecklists 
     where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
     and   ack_sequence = 110
     and   ack_finding is not null;
     vObjNextAccDate := trunc(add_months(o7gttime(ock.ock_org),12));
     vObjAssessReq := '+';
     if v_110Notes is null then
        iErrMsg := 'Please fill in notes for checklist item 110';
        raise err;
     end if;
    exception when no_data_found then
      vObjCond := null;
      vObjNextAccDate := null;
      vObjAssessReq := null;
    end;
    --120 CHECK notes
    /*begin
      select ack_notes into v_120Notes
      from r5actchecklists 
      where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
      and   ack_sequence = 120;
      if v_120Notes is null then
        iErrMsg := 'Please fill in notes for checklist item 120';
        raise err;
     end if;
    exception when no_data_found then
      null;
    end;*/
    
    --140 Criticality
    --When checklist sequence 140 is answered and validated, the plan is to edit the field  OBJ_CRITICALITY   
    begin 
      select 
      case when ack_finding = 'CRI1' then '1'
      when ack_finding = 'CRI2' then '2'
      when ack_finding = 'CRI3' then '3'
      end into vObjCrit
      from r5actchecklists 
      where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
      and   ack_sequence = 140
      and   ack_finding is not null; 
    exception when no_data_found then
      vObjCrit := null;
    end;
    --if both  OBJ_CRITICALITY and OBJ_UDFCHAR21 not empty, we would like for the field OBJ_UDFNUM02 to contain the value of OBJ_CRITICALITY * OBJ_UDFCHAR21
    if vObjCond is not null and vObjCrit is not null then
       vObjRisk := to_number(vObjCond) * to_number(vObjCrit);
    else
       vObjRisk := null;
    end if;
    --150 --OBJ_UDFCHAR16  
    --Poistion User Code If note from checklist sequence 150 is not empty and answer to checklist is yes, please populate value of note in OBJ_UDFCHAR16 (Position User Code)
    begin
      select substr(ack_notes,1,80) into vObjPosC
      from r5actchecklists 
      where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
      and   ack_sequence = 150
      and   ack_yes = '+' and ack_notes is not null;  
    exception when no_data_found then
      vObjPosC := null;
    end;
    --160 --OBJ_SAFETY 
    -- If answer to checklist sequence 160 is yes, please tick box OBJ_SAFETY, otherwise please untick box OBJ_SAFETY
    begin
       select ack_yes into vObjSafe
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 160
       and   ack_yes = '+';
    exception when no_data_found then
       vObjSafe := '-';
    end;
    --If answer to checklist sequence 170 is not empty, please use value to update OBJ_REPLACEMENTVALUE
    begin
       select ack_value into vObjRepV
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 170
       and   ack_value is not null;
    exception when no_data_found then
       vObjRepV := null;
    end;
    --If answer to checklist sequence 180 is not empty, please use value to update  OBJ_YEARBUILT  
    begin
       select substr(ack_value,1,4) into vObjBuiY
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 180
       and   ack_value is not null;
    exception when no_data_found then
       vObjBuiY := null;
    end;
    --If note from checklist sequence 190 is not empty and answer to checklist is yes, please populate value of note in  OBJ_MANUFACTMODEL 
    begin
       select substr(ack_notes,1,30) into vObjMode
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 190
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjMode := null;
    end;
    --If note from checklist sequence 200 is not empty and answer to checklist is yes, please populate value of note in   OBJ_UDFCHAR30
    begin
       select substr(ack_notes,1,80) into vObjModN
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 200
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjModN := null;
    end;
    -- If note from checklist sequence 210 is not empty and answer to checklist is yes, please populate value of note in    OBJ_SERIALNO 
    begin
       select substr(ack_notes,1,30) into vObjSerN
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 210
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjSerN := null;
    end;
    -- If note from checklist sequence 220 is not empty and answer to checklist is yes, please populate value of note in    OBJ_SERIALNO  ??OBJ_UDFCHAR32 material type
    begin
       select substr(ack_notes,1,80) into vObjMatT
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 220
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjMatT := null;
    end;
    --If note from checklist sequence 230 is not empty and answer to checklist is yes, please populate value of note in    OBJ_UDFCHAR33   equipment size 
    begin
       select substr(ack_notes,1,80) into vObjSize
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 230
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjSize := null;
    end; 
    -- When checklist sequence 240 is answered and validated, the plan is to edit the field   OBJ_UDFCHAR18     with the following mapping:  
    begin
      select 
      case when ack_finding = 'METE' then 'm.'
      when ack_finding = 'KILL' then 'KLT'
      when ack_finding = 'KILO' then 'kg'
      end into vObjSizeUom
      from r5actchecklists 
      where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
      and   ack_sequence = 240
      and   ack_finding is not null; 
    exception when no_data_found then
       vObjSizeUom := null;
    end;
    --If note from checklist sequence 250 is not empty and answer to checklist is yes, please populate value of note in    OBJ_UDFCHAR34             
    begin
       select substr(ack_notes,1,80) into vObjSpec
       from r5actchecklists 
       where ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
       and   ack_sequence = 250
       and   ack_yes ='+' and ack_notes is not null;
    exception when no_data_found then
       vObjSpec := null;
    end;
    
    --Validate COND document for 130
    /*select count(1) into vCondDoc
    from  r5docentities dae,r5actchecklists ack
    where ack_code = dae_code
    and   dae_entity = 'OPCL'  
    and   ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
    and   ack_sequence = 131
    and   ack_completed = '+';
    if vCondDoc = 0 then 
       iErrMsg := 'No attachement is found for checklist item 131';
       raise Err;
    end if;*/
     
    
    update r5objects obj set
    obj_udfchar21 = nvl(vObjCond,obj_udfchar21),
    obj_udfdate01 = nvl(vObjNextAccDate,obj_udfdate01),
    obj_udfchkbox01 = nvl(vObjAssessReq,obj_udfchkbox01),
    obj_criticality = nvl(vObjCrit,obj_criticality),
    obj_udfnum02 = nvl(vObjRisk,obj_udfnum02),
    obj_udfchar15 = nvl(vObjPosC,obj_udfchar15),
    obj_udfchar16 = case when obj_obtype = '06EQ' then nvl(vObjPosC,obj_udfchar16) else obj_udfchar16 end,
    obj_safety = nvl(vObjSafe,obj_safety),
    obj_replacementvalue = nvl(vObjRepV,obj_replacementvalue),
    obj_yearbuilt = nvl(vObjBuiY,obj_yearbuilt),
    obj.obj_manufactmodel = nvl(vObjMode,obj_manufactmodel),
    obj.obj_udfchar30 = nvl(vObjModN,obj_udfchar30),
    obj.obj_serialno = nvl(vObjSerN,obj_serialno),
    obj.obj_udfchar32 = nvl(vObjMatT,obj_udfchar32),
    obj.obj_udfchar33 = nvl(vObjSize,obj_udfchar33),
    obj.obj_udfchar18 = nvl(vObjSizeUom,obj_udfchar18),
    obj.obj_udfchar34 = nvl(vObjSpec,obj_udfchar34)
    where obj_code = ock.ock_object and obj_org = ock.ock_object_org;
    
    --sequence 250 If any photo is captured from this questions, please link the photo as a document to the asset with classe PLATE (Only available on the test server)
    --sequence 230  
      --? Checklist answer PHOT will match document class PHOTO
      --? Checklist answer COND will match document class COND (Document class only created on test server so far)
    /*insert into r5docentities
    (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
    select 
    dae_document,'OBJ','OBJ',dae_type,dae_rtype,ock.ock_object||'#'||ock.ock_object_org,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo
    from r5docentities 
    where dae_entity = 'OPCL'
    and   exists 
    (select 1 from r5actchecklists 
    where   ack_rentity = 'OPCK' and ack_entitykey = ock.ock_code and ack_entityorg = ock.ock_org
    and     ack_sequence in (130,250)
    and     ack_code = dae_code);*/
    
    for rec_opdoc in cur_opdoc(ock.ock_code,ock.ock_org) loop
        vDocClass:=null;
        if rec_opdoc.ack_sequence = 135 and rec_opdoc.ack_completed ='+' then
           vDocClass := 'PHOTO';
        elsif rec_opdoc.ack_sequence = 131 and rec_opdoc.ack_completed ='+' then
           vDocClass := 'COND';
        elsif rec_opdoc.ack_sequence = 250 and rec_opdoc.ack_yes ='+' then
           vDocClass := 'PLATE';
        end if;
        update r5documents DOC
        set  doc_class = vDocClass, doc_class_org = '*',
        DOC_DESC = DOC_DESC || ' - '|| to_char(o7gttime(ock.ock_org),'DD-MON-YYYY'),--nvl(vSessionDesc, 'For Operator Checklsit' || ock.ock_code),
        --DOC_TITLE 
        DOC_DATEEFFECTIVE =o7gttime(ock.ock_object_org),
        DOC.DOC_DATEEXPIRED = o7gttime(ock.ock_object_org) + 365
        where doc_code = rec_opdoc.dae_document;
        
        select count(1) into vCount
        from r5docentities 
        where dae_document =  rec_opdoc.dae_document and dae_entity = 'OBJ'
        and dae_code = ock.ock_object||'#'||ock.ock_object_org;
        if vCount = 0 then
          insert into r5docentities
         (dae_document,dae_entity,dae_rentity,dae_type,dae_rtype,dae_code,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo)
          select 
          dae_document,'OBJ','OBJ',dae_type,dae_rtype,ock.ock_object||'#'||ock.ock_object_org,dae_copytowo,dae_printonwo,dae_copytopo,dae_printonpo,dae_createcopytowo
          from r5docentities 
          where dae_entity = 'OPCL'
          and   dae_code = rec_opdoc.ack_code;
        end if;
        
    end loop;
   end if; --end tsk_class ='CONA'
  end if;--end status = c
exception 
  when err then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
   RAISE_APPLICATION_ERROR (SQLCODE,'Error in Flex r5operatorchecklists/Post Update/10/'||substr(SQLERRM, 1, 500)) ; 
end;