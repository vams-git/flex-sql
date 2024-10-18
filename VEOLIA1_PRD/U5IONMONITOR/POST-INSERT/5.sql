declare 
  ion           u5ionmonitor%rowtype;
  chk           VARCHAR2(3);
  vTransID      r5interface.int_transid%type; 

begin
  select * into ion from u5ionmonitor where rowid=:rowid;
  if ion.ion_transid = -1 AND ion.ion_source ='QTN' then
     r5o7.o7maxseq(vTransID, 'INTERFACE', '1', chk);
     
     update u5ionmonitor
     set ion_transid = vTransID,
     ion_create = sysdate,--o7gttime(ion.ion_source),
     created = sysdate,--o7gttime(ion.ion_source),
     createdby = o7sess.cur_user
     where rowid =:rowid;
  end if;
  
exception when others then 
  return;
end;
