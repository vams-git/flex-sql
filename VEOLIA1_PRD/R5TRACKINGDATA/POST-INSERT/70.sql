DECLARE
e_NO_OBJ      exception;
e_NO_CODE      exception;
e_ERR_ADRTYPE     exception;
e_ERR_ADDR     exception;


i_addrFullAddr		VARCHAR2(2000);
i_adrrentity	varchar2(80);
vFailureEffect    varchar2(400);
C1 R5TRACKINGDATA%ROWTYPE;
i_count		int;
i_len		int;
i_flag		VARCHAR2(8);
i_adrcode	VARCHAR2(80);

BEGIN

i_count :=0;
i_flag :='INS';
SELECT * INTO C1 FROM R5TRACKINGDATA
WHERE ROWID = :ROWID;

IF C1.TKD_TRANS = 'ADDR' THEN 

    i_adrrentity := nvl(C1.tkd_promptdata15,'OBJ');

    if i_adrrentity ='OBJ' then
      select count(1) into i_count from r5objects
      where obj_org = C1.tkd_promptdata1 and obj_code =C1.tkd_promptdata2 and obj_notused = '-';
      if i_count  = 0 then
        raise e_NO_OBJ;
      end if;
      i_adrcode := C1.tkd_promptdata2 || '#' || C1.tkd_promptdata1;
    end if;
    if i_adrrentity ='COMP' then
      select count(1) into i_count from r5companies
      where com_org = C1.tkd_promptdata1 and com_code =C1.tkd_promptdata2;
      --and obj_notused = '-';
      if i_count  = 0 then
        raise e_NO_CODE;
      end if;
      i_adrcode := C1.tkd_promptdata2 || '#' || C1.tkd_promptdata1;
    end if;


    if C1.tkd_promptdata3 not in ('D','M','I') then
      raise e_ERR_ADRTYPE;
    end if;

    if C1.tkd_promptdata4 is not null then--addr1
       i_addrFullAddr:= i_addrFullAddr || C1.tkd_promptdata4;
    end if;
    if C1.tkd_promptdata5 is not null then--addr2
       i_addrFullAddr:= i_addrFullAddr || chr(10)|| C1.tkd_promptdata5;
    end if;
    if C1.tkd_promptdata6 is not null then--addr3
       i_addrFullAddr:= i_addrFullAddr || chr(10) || C1.tkd_promptdata6;
    end if;
    if C1.tkd_promptdata7 is not null then--city
       i_addrFullAddr:= i_addrFullAddr || chr(10) || C1.tkd_promptdata7;
    end if;
    if C1.tkd_promptdata8 is not null or C1.tkd_promptdata9 is not null then
       i_addrFullAddr:= i_addrFullAddr || ',';
    end if;
    if C1.tkd_promptdata8 is not null then--state
       i_addrFullAddr:= i_addrFullAddr || ' ' || C1.tkd_promptdata8;
    end if;
    if C1.tkd_promptdata9 is not null then--zipcode
       i_addrFullAddr:= i_addrFullAddr || ' ' ||  C1.tkd_promptdata9;
    end if;
    if  C1.tkd_promptdata10 is not null then--country
       i_addrFullAddr:= i_addrFullAddr || chr(10) ||  C1.tkd_promptdata10;
    end if;

    i_len := length(i_addrFullAddr);
    if i_len <= 0 and i_len > 2000 then
      raise e_ERR_ADDR;
    end if;

    select count(1) into i_count from r5address
    where adr_rentity = i_adrrentity and adr_code = i_adrcode and adr_rtype = C1.tkd_promptdata3;
    if i_count > 0 then
      i_flag := 'UPD';
    end if;
    if i_flag  ='INS' then
      insert into r5address
      (adr_rentity,adr_code,adr_rtype,adr_address1,adr_address2,adr_address3,
      adr_city,adr_state,adr_zip,adr_country,
      adr_phone,adr_phoneextn,adr_fax,adr_email,adr_text)
      values
      (i_adrrentity,i_adrcode,C1.tkd_promptdata3,C1.tkd_promptdata4,C1.tkd_promptdata5,C1.tkd_promptdata6,
      C1.tkd_promptdata7,C1.tkd_promptdata8,C1.tkd_promptdata9,C1.tkd_promptdata10,
      C1.tkd_promptdata11,C1.tkd_promptdata12,C1.tkd_promptdata13,C1.tkd_promptdata14,i_addrFullAddr
      );
    else
      update r5address
      set
      adr_address1   = C1.tkd_promptdata4,
      adr_address2   = C1.tkd_promptdata5,
      adr_address3   = C1.tkd_promptdata6,
      adr_city       = C1.tkd_promptdata7,
      adr_state      = C1.tkd_promptdata8,
      adr_zip        = C1.tkd_promptdata9,
      adr_country    = C1.tkd_promptdata10,
      adr_phone      = C1.tkd_promptdata11,
      adr_phoneextn  = C1.tkd_promptdata12,
      adr_fax        = C1.tkd_promptdata13,
      adr_email      = C1.tkd_promptdata14,
      adr_text       = i_addrFullAddr
      where adr_rentity = i_adrrentity and adr_code = i_adrcode and adr_rtype = C1.tkd_promptdata3;
    end if;
    o7interface.trkdel(c1.tkd_transid);
END IF;
  EXCEPTION
     WHEN e_NO_OBJ THEN
     RAISE_APPLICATION_ERROR(-20005, 'Can not find the Equipment information in GAMA!');
     WHEN e_NO_CODE THEN
     RAISE_APPLICATION_ERROR(-20005, 'Can not find record in GAMA!');
     WHEN e_ERR_ADRTYPE THEN
     RAISE_APPLICATION_ERROR(-20005, 'Please fill in validate address type (D,M or I).');
     WHEN e_ERR_ADDR THEN
     RAISE_APPLICATION_ERROR(-20005, 'Address cannot be blank and must be less than 2000 characters');
    WHEN no_data_found then 
      null;
     WHEN OTHERS then
     RAISE_APPLICATION_ERROR(-20005, SQLCODE || SQLERRM);
  END;