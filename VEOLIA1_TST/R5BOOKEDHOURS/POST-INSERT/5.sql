declare
 boo          r5bookedhours%rowtype;
 vActualHrs   r5bookedhours.boo_hours%type;
 vPerEmail    r5personnel.per_emailaddress%type;
 vShiftStartDate  r5bookedhours.boo_udfdate02%type;
 vLastBookType    r5bookedhours.boo_octype%type;
begin
 select * into boo from r5bookedhours where rowid=:rowid;
 
 if boo.boo_event is not null and boo.boo_person is not null then
    select sum(nvl(boo_orighours,boo_hours)) into vActualHrs
    from r5bookedhours where boo_event=boo.boo_event and boo_person is not null;
    update r5events 
    set evt_udfnum06= nvl(vActualHrs,0)
    where evt_code = boo.boo_event
    and   nvl(evt_udfnum06,0) <> nvl(vActualHrs,0);
    
    /******Get Shift start date for same email address but may cross over different org****/
    select nvl(per_emailaddress,per_code) into vPerEmail 
    from r5personnel p where p.per_code = boo.boo_person;
    if vPerEmail is not null then
        select min(bs.boo_date) into vShiftStartDate
        from  r5bookedhours bs,r5personnel ps
        where bs.boo_person = ps.per_code
        and   bs.boo_correction_ref is null
        and   upper(nvl(ps.per_emailaddress,ps.per_code)) = upper(vPerEmail)
        and   bs.boo_date <= boo.boo_date
        and 
        (
        case when decode(boo.boo_off,null,86400,boo.boo_off) = 86400 then boo.boo_date + 1  ELSE
        to_date(to_char(boo.boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo.boo_off/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo.boo_off,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') 
        end
        -
        case when decode(bs.boo_off,null,86400,bs.boo_off) = 86400 then bs.boo_date + 1  ELSE
        to_date(to_char(bs.boo_date,'YYYY-MM-DD')||' '||to_char(trunc(bs.boo_off/3600), 'FM9999999900')||':'|| to_char(trunc(mod(bs.boo_off,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') 
        end
        )*24>=0 
        and 
        (
        case when decode(boo.boo_off,null,86400,boo.boo_off) = 86400 then boo.boo_date + 1  ELSE
        to_date(to_char(boo.boo_date,'YYYY-MM-DD')||' '||to_char(trunc(boo.boo_off/3600), 'FM9999999900')||':'|| to_char(trunc(mod(boo.boo_off,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') 
        end
        -
        case when decode(bs.boo_off,null,86400,bs.boo_off) = 86400 then bs.boo_date + 1  ELSE
        to_date(to_char(bs.boo_date,'YYYY-MM-DD')||' '||to_char(trunc(bs.boo_off/3600), 'FM9999999900')||':'|| to_char(trunc(mod(bs.boo_off,3600)/60), 'FM00'),'YYYY-MM-DD HH24:MI') 
        end
        )*24<=10;
        
        if boo.boo_ocrtype ='N' and trunc(vShiftStartDate) <> trunc(boo.boo_date) then
           begin
              --get last booked hours type if it is overtime, reset shift start to book date
              select boo_ocrtype into vLastBookType
              from  r5bookedhours bs
              where bs.boo_acd = (
                  SELECT MAX(boo_acd)
                  FROM r5bookedhours b2,r5personnel p2
                  WHERE b2.boo_person = p2.per_code
                  and   b2.boo_correction_ref is null
                  and   upper(nvl(p2.per_emailaddress,p2.per_code)) = upper(vPerEmail)
                  AND   boo_date <= boo.boo_date
                  AND   boo_date >= add_months(boo.boo_date, -30)
                  and   boo_acd < boo.boo_acd               
              );
              if vLastBookType ='O' then
                 vShiftStartDate := trunc(boo.boo_date);
              end if;
            exception when no_data_found then
               null;
            end;
        end if;
        
        update r5bookedhours
        set boo_udfdate02 = vShiftStartDate
        where boo_code = boo.boo_code;
    end if;
 end if;

exception 
  when others then
  RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5BOOKEDHOURS/Post Insert/5' ||SQLCODE || SQLERRM);
end;
