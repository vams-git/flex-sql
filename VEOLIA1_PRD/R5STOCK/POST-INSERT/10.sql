declare 
   sto     r5stock%rowtype;
   vCount  number;
begin
   select * into sto from r5stock where rowid=:rowid;
   select count(1) into vCount
   from  r5binstock
   where bis_store=sto.sto_store 
   and   bis_part=sto.sto_part and bis_part_org=sto.sto_part_org;
   if vCount =0 then
      insert into r5binstock
      (BIS_PART,BIS_PART_ORG,BIS_STORE,BIS_BIN,BIS_LOT,BIS_QTY,BIS_CREATED,BIS_CREATEDBY)
      values
      (sto.sto_part,sto.sto_part_org,sto.sto_store,nvl(sto.sto_defaultbin,'*'),'*',0,o7gttime(sto.sto_part_org),o7sess.cur_user);
   end if;
   
exception when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;
