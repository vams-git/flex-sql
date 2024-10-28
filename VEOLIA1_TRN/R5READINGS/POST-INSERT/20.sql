declare 
  rea              r5readings%rowtype;
  mur             u5u5murule%rowtype;
  
  vLastReadDate    r5readings.rea_date%type;
  vLastReading     r5readings.rea_reading%type;
  vDiffDay         number;
  vMaxDiff         number;
  vCurrDayValue    number;
  
  iErrMsg          varchar2(400);
  err_val          exception;
   
begin
  select * into rea from r5readings where rowid=:rowid;
  begin
     select * into mur from u5u5murule where mur_org = rea.rea_object_org and upper(mur_uom)= upper(rea.rea_uom);
      --get last reading date
      select  rea_date,rea_reading 
      into    vLastReadDate,vLastReading
      from (
       select rea_date,rea_reading 
       from r5readings
       where rea_object = rea.rea_object and rea_object_org = rea.rea_object_org
       and   rea_uom = rea.rea_uom
       and   trunc(rea_date) < trunc(rea.rea_date)
       and   rowid <> :rowid
       order by rea_date desc
      ) where rownum <=1;
      
      --Get current read date accmulate value
      begin
        select sum(rea_diff) into vCurrDayValue
        from r5readings
        where rea_object = rea.rea_object and rea_object_org = rea.rea_object_org
        and   rea_uom = rea.rea_uom
        and   trunc(rea_date) = trunc(rea.rea_date);
     exception when no_data_found then
        vCurrDayValue := 0;         
     end;
      
      if mur.mur_intervaluom ='D' then
         vDiffDay := trunc(rea.rea_date) - trunc(vLastReadDate) ;
         vMaxDiff := round(vDiffDay * mur.mur_interval * mur.mur_limitupper,2);
         if vCurrDayValue > vMaxDiff then
            iErrMsg := 'Daily Meter reading difference '|| vCurrDayValue || ' ' || rea.rea_uom || ' exceeds daily limit '|| vMaxDiff ;
            raise err_val;
         end if;
      end if;
      
      if mur.mur_intervaluom ='H' then
          vDiffDay := (rea.rea_date - vLastReadDate) * 24;
          vMaxDiff := round(vDiffDay * mur.mur_interval * mur.mur_limitupper,2);
          if rea.rea_diff > vMaxDiff then
            iErrMsg := 'Meter reading difference '|| rea.rea_diff  || ' ' || rea.rea_uom || ' exceeds hourly limit '|| vMaxDiff ;
            raise err_val;
          end if;
      end if;
     

  exception when no_data_found then
    null;
  end;
  
exception 
when err_val then
    RAISE_APPLICATION_ERROR ( -20003, iErrMsg ) ;
when others then 
    RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/R5READINGS/Insert/20/' ||substr(SQLERRM, 1, 500)) ; 
end;