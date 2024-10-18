declare
   obj           r5objects%rowtype;
   vWBS          r5costcodes.cst_code%type;
   cWBS          number;
   vCompCode     r5organization.org_udfchar09%type;
   
   vCnt          number;
   iErrMsg       varchar2(200);
   err_val       exception;
   
   
begin
    select * into obj from r5objects where rowid=:rowid;
    if obj.obj_udfchar37 is not null then
      begin 

       select org_udfchar09 into vCompCode from r5organization where org_code = obj.obj_org;

       select count(1) into cWBS
       from r5costcodes 
       where cst_udfchar01 = obj.obj_udfchar37
       and   cst_class = 'WBS' and cst_notused ='-'
       and   cst_code like vCompCode ||'%'
       and   cst_code NOT like '%-600-%';

       select cst_code into vWBS
       from r5costcodes 
       where cst_udfchar01 = obj.obj_udfchar37
       and   cst_class = 'WBS' and cst_notused ='-'
       and   cst_code like vCompCode ||'%'
       and   cst_code NOT like '%-600-%'
       and   rownum < =1;
       if nvl(vWBS,' ') <> nvl(obj.obj_costcode,' ') and cWBS = 1 then
          update r5objects 
          set obj_costcode = vWBS
          where obj_org = obj.obj_org and obj_code = obj.obj_code;
       end if;
      exception when no_data_found then
       null;
      end;
    end if;
    
    if obj.obj_obrtype ='A' and obj.obj_udfchkbox03 = '+' then
       select count(1) into vCnt from U5OUFMEA 
       where OUF_OBJECT = obj.obj_code AND OUF_OBJECT_ORG = obj.obj_org
       and OUF_NOROUREASON is not null 
       and OUF_NOROUREASON in (select uuc_desc from U5UUCODE WHERE UUC_ENTITY = 'OUF_NOROUREASON');
       if vCnt = 0 then
          iErrMsg := 'Please select No Routine reason in  FMEA(Veolia) tab.';
          raise err_val;  
       end if;
    end if;

exception 
  when err_val then
     RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ; 
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Update/40/'||SQLCODE || SQLERRM) ; 
end;