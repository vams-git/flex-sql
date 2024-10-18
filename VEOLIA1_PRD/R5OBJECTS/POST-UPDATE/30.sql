declare
     vobj_obtype r5objects.obj_obtype%type;
     vobj_code   r5objects.obj_code%type;
     vobj_serialno r5objects.obj_serialno%type;

begin

    select obj_code, obj_obtype, obj_serialno
    into vobj_code, vobj_obtype, vobj_serialno
    from r5objects
    where rowid=:rowid;

    if ((vobj_obtype='COUN' or vobj_obtype='REGN' 
        or vobj_obtype='OPCT') and (vobj_serialno='SUPORG')) then
        
         delete from r5userorganization
         where uog_org=vobj_code
         and uog_common='+'
         and uog_org<>'*'
         and uog_user<>O7SESS.cur_user;

    end if;

end;