declare 
  ucd         u5vucosd%rowtype;
  
  cursor cur_cstgrp is
  select * from (
  select cst_code,cst_desc,cst_udfchar01,cst_udfchar02,
  cug_costcode,Listagg(cug_grpcode, ' ') WITHIN GROUP (ORDER BY cug_grpcode) as cst_grp  
  from U5CURGRP,r5costcodes
  where cug_costcode = cst_udfchar01
  group by cst_code,cst_desc,cst_udfchar01,cst_udfchar02,cug_costcode
  ) where nvl(cst_udfchar02,' ') <> cst_grp;

begin
  select * into ucd from u5vucosd where rowid=:rowid;
  if ucd.ucd_id = 4 and ucd.ucd_recalccost = '+' then
     for rec_cstgrp in cur_cstgrp loop
        begin
          update r5costcodes set cst_udfchar02 = rec_cstgrp.cst_grp
          where cst_code = rec_cstgrp.cst_code;
        exception when no_data_found then
          null;
        end;
     end loop;
     update u5vucosd set ucd_recalccost = '-',ucd_updated = sysdate where rowid=:rowid;
  end if;
  
end;