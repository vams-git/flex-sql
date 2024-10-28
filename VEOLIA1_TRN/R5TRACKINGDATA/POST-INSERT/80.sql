DECLARE
tkd       r5trackingdata%rowtype;
vParDesc  r5parts.par_desc%type;

vCnt      number;
iErrMsg   varchar2(400);
val_err   exception;

begin

  select * into tkd from r5trackingdata where rowid =:rowid;
  if tkd.tkd_trans = 'UPOG' then
     select count(1) into vCnt from r5organization where org_code = tkd.tkd_promptdata1;
     if vCnt = 0 then
         iErrMsg := 'Organization is not found for VAMS.';
         raise val_err;
     end if;
     begin
       select par_desc into vParDesc from r5parts where par_code = tkd.tkd_promptdata2 and par_org = tkd.tkd_promptdata3
       and    par_udfchar01 in ('ZGAM','ZSER')
       and    par_notused = '-';
     exception when no_data_found then
        iErrMsg := 'ZGAM/ZSER Part is not found for VAMS.';
        raise val_err;
     end;
     
     select count(1) into vCnt from u5puporg 
     where pog_org = tkd.tkd_promptdata1
     and   pog_part = tkd.tkd_promptdata2 and pog_part_org = tkd.tkd_promptdata3;
     if vCnt = 0 then
        insert into u5puporg
        (pog_org,pog_part,pog_part_org,pog_partdesc,created,createdby,updatecount)
        values
        (tkd.tkd_promptdata1,tkd.tkd_promptdata2,tkd.tkd_promptdata3,vParDesc,o7gttime(tkd.tkd_promptdata3),o7sess.cur_user,0);
     else
       iErrMsg := 'Record is exists.';
        raise val_err ;
     end if;
     
     --delete from r5trackingdata where rowid=:rowid;
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  

exception
   when no_data_found then 
   null;
   WHEN val_err THEN
   RAISE_APPLICATION_ERROR(-20005, iErrMsg);
   WHEN OTHERS then
   RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/80/' ||SQLCODE || SQLERRM) ;
END;