declare 
 sapuom           u5sapuom%rowtype;
 chk              VARCHAR2(3);
 vCount           number; 
 vUOM             VARCHAR2(30);
 err_val          exception;
 iErrMsg          varchar2(500);        
 
begin
  select * into sapuom from u5sapuom where rowid=:rowid;
  select count(sum_sapinternalcode) into vCount
  from u5sapuom 
  where sum_uom = sapuom.sum_uom and sum_sapinternalcode is not null;
  if vCount > 1 then
    iErrMsg := 'Only one mapping is allowed for SAP Internal UOM';
   raise err_val;
  end if;
  
  select count(1) into vCount
  from u5sapuom 
  where sum_sapisocode = sapuom.sum_sapisocode;
  if vCount > 1 then
    begin 
      select sum_uom into vUOM
      from u5sapuom 
      where sum_sapisocode = sapuom.sum_sapisocode
     and sum_uom <> sapuom.sum_uom;
    exception when others then
      vUOM := null;
    end;
    iErrMsg := 'SAP ISO UOM code is exists for UOM ' || vUOM;
    raise err_val;
  end if;
  
exception 
  when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
  when others then 
    RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/u5sapuom/Insert/100') ; 
end;