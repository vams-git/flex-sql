declare 
  osr           u5oustcr%rowtype;
  vObj          r5objects.obj_code%type;
  vOrg          r5objects.obj_org%type;
  
  vRootCode     r5objects.obj_code%type;
  vRootOrg      r5objects.obj_org%type;
  vRootType     r5objects.obj_obtype%type;
  vRootDesc     r5objects.obj_desc%type;
  vLvlDesc      r5objects.obj_desc%type;

  
  vUdf01 varchar2(80);vUdf02 varchar2(80);vUdf03 varchar2(80);vUdf04 varchar2(80);
  vUdf05 varchar2(80);vUdf06 varchar2(80);vUdf07 varchar2(80);vUdf08 varchar2(80);
  vUdf09 varchar2(80);vUdf10 varchar2(80);vUdf11 varchar2(80);vUdf12 varchar2(80);
  vUdf13 varchar2(80);vUdf14 varchar2(80);vUdf15 varchar2(80);vUdf16 varchar2(80);  
  
  iErrMsg       varchar2(200);
  errval        exception;
  
  cursor cur_parent is 
  select stc_parent_org,stc_parent,stc_parenttype,level
  ,ltrim(sys_connect_by_path(stc_child ,'/'),'/') path
  ,ltrim(sys_connect_by_path(stc.stc_childtype ,'/'),'/') typepath
  from  r5structures stc
  connect by  prior stc_parent = stc_child  AND prior stc_parent_org = stc_child_org
  start with stc_child =vObj and stc_child_org = vOrg
  order by stc_parenttype;
  
  cursor cur_child is 
  select
  stc_parent
  ,stc_child_org
  ,stc_child
  ,stc_childtype
  ,level as stc_level
  ,ltrim(sys_connect_by_path(stc_child ,'/'),'/') stc_path
  ,ltrim(sys_connect_by_path(stc.stc_childtype ,'/'),'/') typepath
  ,trim(SYS_CONNECT_BY_PATH(decode(level,1,stc_childtype,''), ' ')) AS L1Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,1,stc_child,''), ' ')) AS L1
  ,trim(SYS_CONNECT_BY_PATH(decode(level,2,stc_childtype,''), ' ')) AS L2Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,2,stc_child,''), ' ')) AS L2
  ,trim(SYS_CONNECT_BY_PATH(decode(level,3,stc_childtype,''), ' ')) AS L3Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,3,stc_child,''), ' ')) AS L3
  ,trim(SYS_CONNECT_BY_PATH(decode(level,4,stc_childtype,''), ' ')) AS L4Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,4,stc_child,''), ' ')) AS L4
  ,trim(SYS_CONNECT_BY_PATH(decode(level,5,stc_childtype,''), ' ')) AS L5Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,5,stc_child,''), ' ')) AS L5
  ,trim(SYS_CONNECT_BY_PATH(decode(level,6,stc_childtype,''), ' ')) AS L6Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,6,stc_child,''), ' ')) AS L6
  ,trim(SYS_CONNECT_BY_PATH(decode(level,7,stc_childtype,''), ' ')) AS L7Type
  ,trim(SYS_CONNECT_BY_PATH(decode(level,7,stc_child,''), ' ')) AS L7
  from r5structures stc
  connect by  prior stc_child = stc_parent AND prior stc_child_org = stc_parent_org
  start with stc_parent = vObj and stc_parent_org = vOrg
  order by stc_childtype;
  
  procedure setUDFValue(vType varchar2,vCode varchar2,vDesc varchar2) is
  begin
      if vType = 'CRTC' then
         vUdf01 := vCode;
         vUdf02 := vDesc;
      elsif vType = '01ST' then
         vUdf03 := vCode;
         vUdf04 := vDesc;
      elsif vType = '02ET' then
         vUdf05 := vCode;
         vUdf06 := vDesc;
      elsif vType = '03UT' then
         vUdf07 := vCode;
         vUdf08 := vDesc;
      elsif vType = '04AS' then
         vUdf09 := vCode;
         vUdf10 := vDesc;
      elsif vType = '05FP' then
         vUdf11 := vCode;
         vUdf12 := vDesc;
      elsif vType = '06EQ' then
         vUdf13 := vCode;
         vUdf14 := vDesc;
      end if;
  end setUDFValue;

  
begin
  select * into osr from u5oustcr where rowid=:rowid;
  if nvl(osr.osr_refreshed,'-') = '-' and osr.osr_status = 'ASSETUDF' then
  begin
    vObj := osr.osr_object;
    vOrg := osr.osr_org;
    
    select 
    case when obj_obtype = 'CRTC' then obj_variable1 else obj_code end as obj_code,
    obj_org,obj_obtype,
    obj_desc
    into vRootCode,vRootOrg,vRootType,vRootDesc
    from   r5objects o
    where  obj_code = vObj and obj_org = vOrg;
    if vRootType not in ('CRTC','01ST','02ET','03UT','04AS','05FP','06EQ','07CP') then
     iErrMsg := 'VAMS Asset Type is not supported.';
     raise errval;
    end if;
    --set root udf value
    setUDFValue(vRootType,vRootCode,vRootDesc);
    
   if vRootType in ('01ST','02ET','03UT','04AS','05FP','06EQ','07CP') then
     --get parent udf value
     for rec_p in cur_parent loop
       select obj_desc into vLvlDesc from r5objects where obj_code = rec_p.stc_parent and obj_org = rec_p.stc_parent_org;
       setUDFValue(rec_p.stc_parenttype,rec_p.stc_parent,vLvlDesc);
     end loop;
   end if;  
   
   for rec_c in cur_child loop
     begin 
      --Set child udf to empty first
     if vRootType ='CRTC' then --udf03-udf14 
       vUdf03:=null;
       vUdf04:=null;
       vUdf05:=null;
       vUdf06:=null;
       vUdf07:=null;
       vUdf08:=null;
       vUdf09:=null;
       vUdf10:=null;
       vUdf11:=null;
       vUdf12:=null;
       vUdf13:=null;
       vUdf14:=null;
     elsif vRootType ='01ST' then --udf05-udf14 
       vUdf05:=null;
       vUdf06:=null;
       vUdf07:=null;
       vUdf08:=null;
       vUdf09:=null;
       vUdf10:=null;
       vUdf11:=null;
       vUdf12:=null;
       vUdf13:=null;
       vUdf14:=null;
     elsif vRootType ='02ET' then --udf07-udf14  
       vUdf07:=null;
       vUdf08:=null;
       vUdf09:=null;
       vUdf10:=null;
       vUdf11:=null;
       vUdf12:=null;
       vUdf13:=null;
       vUdf14:=null;
     elsif vRootType ='03UT' then --udf09-udf14
       vUdf09:=null;
       vUdf10:=null;
       vUdf11:=null;
       vUdf12:=null;
       vUdf13:=null;
       vUdf14:=null;
     elsif vRootType ='04AS' then --udf11-udf14 
       vUdf11:=null;
       vUdf12:=null;
       vUdf13:=null;
       vUdf14:=null;
     elsif vRootType ='05FP' then --udf13-udf14 
       vUdf13:=null;
       vUdf14:=null;
     end if;
     --get child udf 
     if rec_c.L1 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L1 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L1type,rec_c.L1,vLvlDesc);
     end if;
      if rec_c.L2 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L2 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L2type,rec_c.L2,vLvlDesc);
     end if;
      if rec_c.L3 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L3 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L3type,rec_c.L3,vLvlDesc);
     end if;
      if rec_c.L4 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L4 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L4type,rec_c.L4,vLvlDesc);
     end if;
     if rec_c.L5 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L5 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L5type,rec_c.L5,vLvlDesc);
     end if;
     if rec_c.L6 is not null then
      select obj_desc into vLvlDesc from r5objects where obj_code = rec_c.L6 and obj_org = rec_c.stc_child_org;
      setUDFValue(rec_c.L6type,rec_c.L6,vLvlDesc);
     end if;
       
     update r5objects set 
     obj_udfchar01 = vUdf01,--Contract Code(CRTC)
     obj_udfchar02 = vUdf02,--Contract
     obj_udfchar03 = vUdf03,--Site Code(01ST)
     obj_udfchar04 = vUdf04,--Site
     obj_udfchar05 = vUdf05,--System Code(02)
     obj_udfchar06 = vUdf06,--System
     obj_udfchar07 = vUdf07,--Subsystem Code(03UT)
     obj_udfchar08 = vUdf08,--Subsystem
     obj_udfchar09 = vUdf09,--Functional Group Code(04)
     obj_udfchar10 = vUdf10,--Functional Group
     obj_udfchar11 = vUdf11,--Functional Location Code(05FP)
     obj_udfchar12 = vUdf12,--Functional Location
     obj_udfchar13 = vUdf13,--Element code(06EQ)
     obj_udfchar14 = vUdf14--Element
     where obj_code = rec_c.stc_child and obj_org = rec_c.stc_child_org;
     exception 
       when no_data_found then
            RAISE_APPLICATION_ERROR(-20003,rec_c.stc_child||'no_data_found'); 
       when others then
            RAISE_APPLICATION_ERROR(-20003,rec_c.stc_child||substr(SQLERRM, 1, 500));
     end;
   end loop;

   
   if osr.OSR_SKIPWOUDF = '+' then 
     update u5oustcr
     set    osr_refreshed = '+',osr_status = 'COMPLETED',osr_message = 'Asset Hierarchy UDF are updated successfully!'
     where  rowid=:rowid; 
   else
     update u5oustcr
     set    osr_refreshed = '+',osr_status = 'WOUDF',osr_message = 'Asset Hierarchy UDF are updated successfully!'
     where  rowid=:rowid; 
   end if;
  exception when others THEN
     update u5oustcr
     set    osr_message = 'Fail to update Asset Hierarchy UDF '
     where  rowid=:rowid; 
     null;
  end;
  end if;--nvl(osr.osr_refreshed,'-') = '-' and osr.osr_status = 'ASSETUDF' 
    

exception when errval then
  RAISE_APPLICATION_ERROR (-20003,iErrMsg); 
when others then
  RAISE_APPLICATION_ERROR (-20003,'Error in Flex u5oustcr/Post Update/10/'||substr(SQLERRM, 1, 500)) ; 
end;
