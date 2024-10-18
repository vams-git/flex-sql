DECLARE 
  bur         u5burule%rowtype;
  
  vReg        varchar2(80); 
  vCount      number;
  vHourVal    varchar2(1);
  vDate       date;
  vStartDate  date;
  vEndDate    date;
  vBurCode    u5burule.bur_code%type;
  vOn         number;
  vOff        number;
  vDaySeq     number;
  iErrMsg     varchar2(400); 
  err_val     exception;

BEGIN 
  select * into bur from u5burule where rowid=:rowid;
  --validate start time and end time format
  vReg := '^[0-2]{1}[0-4]{1}:[0-5]{1}[0-9]{1}$';
  begin
    vStartDate := to_date('1900-01-01 ' || bur.bur_starthour,'YYYY-MM-DD HH24:MI');
  exception when others then
    iErrMsg := 'Rule Start Time is not valid format.';
    raise err_val;
  end;
  
  if bur.bur_endhour = '00:00' THEN
    iErrMsg := 'Rule End Time cannot be 00:00, please change to 24:00';
    raise err_val;
  end if;
  begin
    if bur.bur_endhour = '24:00' then
       vEndDate := to_date('1900-01-02 00:00','YYYY-MM-DD HH24:MI');
    else 
       vEndDate := to_date('1900-01-01 ' || bur.bur_endhour,'YYYY-MM-DD HH24:MI');
    end if;
  exception when others then
    iErrMsg := 'Rule End Time is not valid format.';
    raise err_val;
  end;
  
  --Validate Overlap time
  begin
    select bur_code into vBurCode
    from   u5burule 
    where  bur_org = bur.bur_org
    and    bur_day = bur.bur_day
    and    bur_pertype = bur.bur_pertype
    and    nvl(bur_mrc,' ') = nvl(bur.bur_mrc,' ')
    and    bur_code <> bur.bur_code
    and    vStartDate > to_date('1900-01-01 ' || bur_starthour,'YYYY-MM-DD HH24:MI')
    and    vStartDate < 
    case when bur_endhour ='24:00' then to_date('1900-01-02 00:00','YYYY-MM-DD HH24:MI')
    else to_date('1900-01-01 ' || bur_endhour,'YYYY-MM-DD HH24:MI') end
    and    rownum <= 1;
    iErrMsg := 'Rule Start Time is overlap with ' || vBurCode;
    raise err_val;
  exception when no_data_found then
    null;
  end;  
  
  begin
    select bur_code into vBurCode
    from   u5burule 
    where  bur_org = bur.bur_org
    and    bur_day = bur.bur_day
    and    bur_pertype = bur.bur_pertype
    and    nvl(bur_mrc,' ') = nvl(bur.bur_mrc,' ')
    and    bur_code <> bur.bur_code
    and    vEndDate > to_date('1900-01-01 ' || bur_starthour,'YYYY-MM-DD HH24:MI')
    and    vEndDate < 
    case when bur_endhour ='24:00' then to_date('1900-01-02 00:00','YYYY-MM-DD HH24:MI')
    else to_date('1900-01-01 ' || bur_endhour,'YYYY-MM-DD HH24:MI') end
    and    rownum <= 1;
    iErrMsg := 'Rule End Time is overlap with ' || vBurCode;
    raise err_val;
  exception when no_data_found then
    null;
  end;   
  
  if vStartDate > vEndDate then
     iErrMsg := 'Rule Start Time must be less than Rule End Time.';
     raise err_val;
  end if;

  vOn  := to_number(substr(bur.bur_starthour,1,2)) * 3600+ to_number(substr(bur.bur_starthour,4,5)) * 60;
  vOff := to_number(substr(bur.bur_endhour,1,2)) * 3600+ to_number(substr(bur.bur_endhour,4,5)) * 60;
  update u5burule set bur_on = vOn where rowid=:rowid and nvl(bur_on,-999) <> vOn;
  update u5burule set bur_off = vOff where rowid=:rowid and nvl(bur_off,-999) <> vOff;
  select case when bur.bur_day ='MON' then 1 
  when bur.bur_day ='TUE' then 2
  when bur.bur_day ='WED' then 3
  when bur.bur_day ='THU' then 4
  when bur.bur_day ='FRI' then 5
  when bur.bur_day ='SAT' then 6
  when bur.bur_day ='SUN' then 7
  when bur.bur_day ='PH' then 8 end into vDaySeq from dual;
  update u5burule set bur_dayseq = vDaySeq where rowid=:rowid and nvl(bur_dayseq,-999) <> vDaySeq;
  
EXCEPTION
WHEN err_val THEN
RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ;   
END;