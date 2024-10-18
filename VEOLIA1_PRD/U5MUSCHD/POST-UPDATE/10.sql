declare 
  msh              u5muschd%rowtype;
  
  vCnt             number;
  vTable           varchar2(30);
  vColumnName      varchar2(30);
  vMPK             r5mailattribs.maa_pk%type;

  err_val          exception;
  iErrMsg          varchar2(500);
  
  cursor cur_msp(vTemplate in varchar2) is
  select * from u5muschp msp
  WHERE msp.msh_template = vTemplate;
  
begin
  select * into msh from u5muschd where rowid=:rowid;
  if msh.msh_status ='U' and msh.msh_maapk is not null then
     delete from r5mailparameters where map_attribpk = msh.msh_maapk;
     delete from r5mailattribs where maa_pk = msh.msh_maapk;
     update u5muschd set msh_maapk = null where rowid=:rowid;
  end if;
  
  if  msh.msh_status ='A' and msh.msh_maapk is null then
      select S5MAILATTRIBS.NEXTVAL into vMPK from dual;
      vTable := 'R5MAILEVENTS';
      select count(1) into vCnt
      from   u5muschp msl
      where  msl.msh_template = msh.msh_template;
      
      insert into r5mailattribs
      (maa_table,maa_template,maa_enteredby,maa_comment,maa_pk,
      maa_insert,maa_update,maa_delete,maa_workflow,maa_includeurl,maa_active,
      maa_oldstatus,maa_newstatus)
      values
      (
      vTable,msh.msh_template,o7sess.cur_user,'System Schedule Please do not moidfy',vMPK,
      '-','+','-','-','-','-',
      'U','U'
      );
      
      for rec_msp in cur_msp(msh.msh_template) loop
        vColumnName := 'MAE_PARAM'||rec_msp.msp_parameter;
        insert into r5mailparameters map
        (map_table,map_template,map_attribpk,
        map_column,
        map_parameter,
        map_reportparameter
        )
        values
        (vTable,rec_msp.msh_template,vMPK,
        vColumnName,
        rec_msp.msp_parameter,
        rec_msp.msp_reportparameter
        );
      end loop;
      
      insert into r5mailparameters map
      (map_table,map_template,map_attribpk,
      map_column,
      map_parameter,
      map_reportparameter
      )
      values
      (vTable,msh.msh_template,vMPK,
      ':mp5user',
      15,
      null
      );
      
      update U5MUSCHD
      set msh_maapk = vMPK
      where rowid =:rowid;
  end if;
  
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;
end;