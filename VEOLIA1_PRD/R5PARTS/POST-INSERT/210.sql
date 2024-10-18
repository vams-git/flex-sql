declare 
  par             r5parts%rowtype;
  cmail           r5mailtemplate.mat_mail%type;
  vTemplate       r5mailtemplate.mat_code%type;
  vManufactPart   r5partmfgs.mfp_manufactpart%type;
  
begin
  select * into par from r5parts where rowid=:rowid;
  if par.par_udfchar01 = 'ZSPA' then
    vTemplate := 'M-AUS-SAPPART-I';
    begin
       select mat_code
       into cmail
       from r5mailtemplate
       where mat_code = vTemplate;
     exception when no_data_found then
       return;
     end;

    begin
     begin
       select mfp_manufactpart into vManufactPart
       from r5partmfgs
       where mfp_part = par.par_code and mfp_part_org = par.par_org
       and mfp_primary ='+';
     exception when no_data_found then
       vManufactPart := null;
     end;

     insert into r5mailevents
     (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
      MAE_PARAM1,MAE_PARAM2,MAE_PARAM3,MAE_PARAM4,MAE_PARAM5,
      MAE_ATTRIBPK)
      VALUES
      (S5MAILEVENT.NEXTVAL,cmail,SYSDATE,'-','N',
       par.par_code,par.par_desc,par.par_uom,vManufactPart,par.par_udfchar20,
       0
      );
    exception
      when no_data_found then
        null;
      when others then
        null;
     end;
  end if;
    
exception 
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5PARTS/Post Insert/210');
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;   
end;