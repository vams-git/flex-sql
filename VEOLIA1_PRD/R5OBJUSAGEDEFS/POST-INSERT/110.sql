DECLARE 
  OUD               R5OBJUSAGEDEFS%ROWTYPE;
  vOBType           varchar2(5);
  vCount            number;

  iErrMsg           varchar2(400); 
  err_val           exception;

BEGIN 
  SELECT * INTO OUD 
  FROM   R5OBJUSAGEDEFS 
  WHERE  ROWID =:ROWID;
  
  select substr(obj_obtype,1,2) into vOBType
  from   r5objects 
  where  obj_code = oud.oud_object and obj_org = oud.oud_object_org;

  if vOBType in ('05') and (oud.oud_parent||oud.oud_child not in ('++')) then 
     iErrMsg :=  'Wrong meter type. Functional Position can have only Parent&Child type of meter.';
     raise err_val;
  end if;

  if vOBType in ('06','07') then
      select
      count(1) into vCount  
      from
      r5structures,r5objects,r5objusagedefs
      where stc_parent = obj_code and stc_parent_org = obj_org
      and   oud_object = obj_code and oud_object_org = obj_org
      and   obj_obtype like '05%'  
      connect by prior stc_parent = stc_child 
      start with stc_child = oud.oud_object;
      if vCount > 0 and (oud.oud_parent||oud.oud_child not in ('++')) then 
        iErrMsg := 'Wrong meter type. Asset can have only only Parent&Child type of meter.';
        raise err_val;
      end if;
  end if;
  
  select count(1) into vCount from R5UOMS
  where uom_code = oud.oud_uom and uom_class = 'METER';
  if (vCount<=0) then
     iErrMsg := 'The unit of measure must be a unit for meters (METER).';
     raise err_val;
  end if;
  
EXCEPTION
WHEN err_val THEN 
RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;

END;