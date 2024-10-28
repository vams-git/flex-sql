declare 
  obj             r5objects%rowtype;
  objchild        r5objects%rowtype;
  vGenDate        date;
  vOpenOPC        number;
  vSameStartOPC   number;
  vOCKCode        r5operatorchecklists.ock_code%type;
  
  cursor cur_child(vParent varchar2,vParentOrg varchar2) is
  select
  stc_child_org,stc_child,stc_childtype,stc_childrtype,
  stc_parent,level
  ,ltrim(sys_connect_by_path(stc_child ,'/'),'/') path
  from
  r5structures
  connect by prior stc_child = stc_parent and prior stc_child_org = stc_parent_org
  start with stc_parent = vParent and stc_parent_org = vParentOrg;
  --start with stc_parent = '5-WSL00103' and stc_parent_org = 'WSL'
begin
  select * into obj from r5objects where rowid=:rowid;

  if obj.obj_udfchar22 is not null and obj.obj_udfchar22 like 'FUNGOPC%' and obj.obj_status in ('VAL') and obj.obj_obrtype in ('P') then
     --vGenDate := obj.obj_udfdate02;
     vGenDate := o7gttime(obj.obj_org);
     for rec_child in cur_child(obj.obj_code,obj.obj_org) loop
         select * into objchild from r5objects where obj_code = rec_child.stc_child and obj_org = rec_child.stc_child_org;
         if objchild.obj_udfchkbox01 = '+' and objchild.obj_status = 'VAL' then
            --Any open OPC for same equipment,created user?
            select count(1) into vOpenOPC
            from r5operatorchecklists 
            where ock_object = objchild.obj_code and ock_object_org = objchild.obj_org
            and   ock_createdby = o7sess.cur_user
            and   ock_rstatus in ('U');
            --Any OPC for same equipmane, created user and same start date
            select count(1) into vSameStartOPC
            from  r5operatorchecklists 
            where ock_object = objchild.obj_code and ock_object_org = objchild.obj_org
            and   ock_createdby = o7sess.cur_user
            and   ock_startdate = vGenDate;
            if vOpenOPC = 0 and vSameStartOPC = 0 then
                
                select S5OPERATORCHECKLISTS.Nextval into vOCKCode from dual;
                insert into r5operatorchecklists
                (ock_code,ock_org,ock_object,ock_object_org,ock_task,ock_taskrev,
                ock_status,ock_rstatus,ock_startdate,ock_created,ock_createdby,
                ock_udfchar01)
                values
                (vOCKCode,objchild.obj_org,objchild.obj_code,objchild.obj_org,'CAUS-T-0001',0,
                'U','U',vGenDate,vGenDate,o7sess.cur_user,
                obj.obj_code);
                
                 o7createactchecklist(
                  null,--event      IN  VARCHAR2,
                  null,--act        IN  NUMBER,
                  null,--'CAUS-T-0001',--task       IN  VARCHAR2,
                  null,--0,--taskrev    IN  NUMBER,
                  null,--lotopk     IN  VARCHAR2,
                  '%',--childwo    IN  VARCHAR2 DEFAULT '%',
                  '-',--routeupd   IN  VARCHAR2 DEFAULT '-',
                  '-',--pointupd   IN  VARCHAR2 DEFAULT '-',
                  null,--objupd     IN  VARCHAR2 DEFAULT '-',
                  vOCKCode,--operatorcl IN  VARCHAR2 DEFAULT NULL,
                  null,--casetask   IN  VARCHAR2 DEFAULT NULL,
                  null--nonconf    IN  VARCHAR2 DEFAULT NULL 
                  );
                  
            end if;   
         end if;
     end loop;
     update r5objects set obj_udfchar22 = null where rowid=:rowid and obj_udfchar22 like 'FUNGOPC%';
  end if;
  
exception 
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5objects/Update/20') ; 
end;