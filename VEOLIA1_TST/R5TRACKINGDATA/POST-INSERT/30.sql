declare 
  tkd           r5trackingdata%rowtype;
  vStatus       u5ousdep.osd_status%type;
  vMsg          u5ousdep.osd_message%type;
  vIDOC       u5ousdep.osd_idoc%type;
  vPstDate      date;
  vItemNum      number;
  vDepValue     number;     
  vObj          r5objects.obj_code%type;
  vObjOrg       r5objects.obj_org%type;
  iErrMsg       varchar2(400);
  err_val       exception;

begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans in ('OBJV') then  -- to be replaed by OBJV
    
       vStatus := 'New';
      
      /*begin
        select obj_code,obj_org into vObj,vObjOrg
        from r5objects 
        where obj_udfchar40 = tkd.tkd_promptdata4;
      exception when no_data_found then
        vObj := null;
        vStatus := 'Fail';
        vMsg := 'Asset is not found!';
      end;*/
      
      --if vObj is not null  then
          
          begin
            vPstDate := to_date(tkd.tkd_promptdata2,'YYYY-MM-DD');
          exception when others then
            vStatus := 'Fail';
            vMsg := 'Date Format is not correct!';
          end;
          begin
            vItemNum := to_number(tkd.tkd_promptdata3);
          exception when others then
            vStatus := 'Fail';
            vMsg := 'Item Number format is not correct!';
          end;
          begin
            vDepValue := to_number(nvl(tkd.tkd_promptdata5,0));
          exception when others then
            vStatus := 'Fail';
            vMsg := 'Depreciation format is not correct!';
          end;
      
      /*begin
        select osd_idoc into vIDOC from u5ousdep
        where osd_sapasset = tkd.tkd_promptdata4 and trunc(osd_date) = trunc(vPstDate);
        if vIDOC is not null then 
         vStatus := 'Fail';
         vMsg := 'Duplicated Asset Depreciation Record with iDOC ' || vIDOC || ' !';
        end if;
      exception when no_data_found then 
          vIDOC := null;
      end;*/
          
        
          insert into u5ousdep 
          (osd_idoc,osd_itemnoacc,osd_sapasset,osd_date,osd_depvalue,osd_curr,osd_glacc,osd_comp,osd_sapcstcode,
           osd_object,osd_object_org,osd_status,osd_message,
           osd_created,osd_createdby,
           created,createdby,updatecount
           )
          values 
          (tkd.tkd_promptdata1,vItemNum,tkd.tkd_promptdata4,vPstDate,vDepValue,tkd.tkd_promptdata6,tkd.tkd_promptdata7,tkd.tkd_promptdata8,tkd.tkd_promptdata9,
          vObj,vOBjOrg,vStatus,vMsg,
          sysdate,o7sess.cur_user,
          sysdate,o7sess.cur_user,0
          );
       --end if;
        
    
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  
exception
  when no_data_found then 
    null;
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/30/' ||SQLCODE || SQLERRM) ;
end;