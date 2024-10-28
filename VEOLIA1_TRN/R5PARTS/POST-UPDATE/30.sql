declare 
  par             r5parts%rowtype;
  vCount          number;
  ncount          number;
  pcount          number;
  iErrMsg         varchar2(500); 
  vMfpPart        r5partmfgs.mfp_part%type; 
  err_validate    exception;
begin
  select * into par from r5parts where rowid=:rowid;
	if o7sess.cur_user NOT IN ('MIGRATION','DATABRIDGEINTERNALUSER','ASSET.MANAGEMENT@VEOLIA.COM') then
	    return;
    end if;
		 
   if par.par_udfchar02 is not null --and pai.pai_manufactpart is not null
       then
         
       select count(1) into vCount
       from r5manufacturers 
       where mfg_code = par.par_udfchar02 and mfg_org = par.par_org;
       
       if vCount = 0 then
          iErrMsg := 'Manufacture is not found in VAMS.';
          raise err_validate;
       end if;
       
        update r5partmfgs
        set    MFP_PRIMARY  = '-'
        where  mfp_part_org = par.par_org and mfp_part = par.par_code
        and    mfp_primary='+';

        select count(1) into ncount from r5partmfgs
        where mfp_part_org = par.par_org and mfp_part = par.par_code
        and mfp_manufacturer = par.par_udfchar02; --and mfp_manufactpart = pai.pai_manufactpart;*/
        /*delete from r5partmfgs
        where mfp_part_org = par.par_org and mfp_part = par.par_code
        and mfp_manufacturer = par.par_udfchar02;*/
        --ncount := 0;
        
        

        if ncount = 0 then
          insert into r5partmfgs(
          MFP_PART,
          MFP_PRIMARY,
          MFP_MANUFACTURER,
          MFP_MANUFACTPART,
          MFP_SOURCESYSTEM,
          MFP_SOURCECODE,
          MFP_PART_ORG,
          MFP_NOTUSED
          ) VALUES
          (par.par_code,
          '+',
          par.par_udfchar02,
          par.par_udfchar03,
          'SAP',
          par.par_udfchar02,
          par.par_org,
          '-'
          );
        end if;
       
        if ncount = 1 then
          update r5partmfgs
          set    MFP_PRIMARY  = '+',
                 MFP_MANUFACTPART = par.par_udfchar03,
                 MFP_NOTUSED = '-'
          where mfp_part_org = par.par_org
          and   mfp_part = par.par_code
          and   mfp_manufacturer = par.par_udfchar02;
        end if;
        
        if ncount > 1 then
           --check is have same part number just update to primary
           select count(1) into pCount from r5partmfgs mfp
           where mfp_part_org = par.par_org and mfp_part = par.par_code
           and mfp_manufacturer = par.par_udfchar02 and mfp_manufactpart = par.par_udfchar03;
           if pCount = 1 then
              update r5partmfgs
              set    MFP_PRIMARY  = '+',
                     MFP_MANUFACTPART = par.par_udfchar03,
                     MFP_NOTUSED = '-'
              where mfp_part_org = par.par_org
              and   mfp_part = par.par_code
              and   mfp_manufacturer = par.par_udfchar02
              and   mfp_manufactpart = par.par_udfchar03;
           end if;
           --or else just get first to update
           if pCount = 0 then
              select mfp_manufactpart into vMfpPart 
              from r5partmfgs  
              where  mfp_part_org = par.par_org and mfp_part = par.par_code
              and    mfp_manufacturer = par.par_udfchar02
              and    rownum <= 1;
              update r5partmfgs
              set    MFP_PRIMARY  = '+',
                     MFP_MANUFACTPART = par.par_udfchar03,
                     MFP_NOTUSED = '-'
              where mfp_part_org = par.par_org
              and   mfp_part = par.par_code
              and   mfp_manufacturer = par.par_udfchar02
              and   mfp_manufactpart = vMfpPart;
           end if;
         end if; --ncount > 1
           


     end if;

exception 
when err_validate then
  RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5PARTS/Post Update/30/' || substr(SQLERRM, 1, 500));
 --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ;  

end;