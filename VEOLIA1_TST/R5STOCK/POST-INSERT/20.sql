declare 
  vOrg  r5organization.org_code%type;
  vPart r5parts.par_code%type;
  
  cmail r5mailtemplate.mat_mail%type;
  rec_par r5parts%rowtype;
  vParam7 r5mailevents.mae_param7%type;
begin
  BEGIN
  SELECT 
  PAR_ORG,PAR_CODE INTO vOrg,vPart
  FROM R5PARTS PAR,R5STOCK STO
  WHERE PAR_CODE = STO_PART AND PAR_ORG = STO_PART_ORG
  AND   PAR_NOTUSED='-' AND PAR_ORG ='CAUS'
  AND   STO_STORE IN ('STO-00163010-A')
  AND   (INSTR(UPPER(PAR_UDFCHAR26),'SAF')>0 OR INSTR(UPPER(PAR_UDFCHAR26),'SUPER DUPLEX')>0)
  AND   STO.ROWID=:ROWID;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN;
  END;
  cmail := 'M-GCD-MATERIAL-QA';
  begin
    select *  into rec_par from r5parts where par_org = vOrg and par_code = vPart;
  exception when no_data_found then
     return;
  end;
  begin
    select --r5o7.o7get_desc('EN','MANU',mfp_manufacturer,'','')
    mfp_manufactpart
    into vParam7
    from r5partmfgs where mfp_part = vOrg and mfp_part_org=vPart
    and mfp_primary='+';
  exception when no_data_found then
    vParam7:=null;
  end;
  insert into r5mailevents
   (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,
    MAE_PARAM1,
    MAE_PARAM2,
    MAE_PARAM3,
    MAE_PARAM4,
    MAE_PARAM5,
    MAE_PARAM6,
    MAE_PARAM7,
    MAE_ATTRIBPK)
    VALUES
    (S5MAILEVENT.NEXTVAL,cmail,SYSDATE,'-','N',
     rec_par.par_code,
     rec_par.par_desc,
     rec_par.par_uom,
     rec_par.par_udfchar27,
     rec_par.par_udfchar26,
     rec_par.par_udfchar25,
     vParam7,
     0--cpk--189
    );
  
exception when others then
   RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;
