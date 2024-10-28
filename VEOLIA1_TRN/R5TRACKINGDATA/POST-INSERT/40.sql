declare 
  tkd           r5trackingdata%rowtype;
  vCnt          number;
  chk           VARCHAR2(3);
  cmsg          r5errtexts.ert_text%type;
  xLoc          r5objects.obj_xlocation%type;
  yLoc          r5objects.obj_ylocation%type;
  iErrMsg       varchar2(400);
  err_val       exception;
  
begin
  
  select * into tkd from r5trackingdata where rowid=:rowid;
  if tkd.tkd_trans = 'IVML' then
    begin
     
      yLoc := round(tkd.tkd_promptdata3,6); --Latitude OBJ_YCOORDINATE,OBJ_YLOCATION
      xLoc := round(tkd.tkd_promptdata4,6);  --longitude OBJ_XCOORDINATE,OBJ_XLOCATION
    
      update r5objects
      set    OBJ_XCOORDINATE = xLoc,
             OBJ_YCOORDINATE = yLoc
      where  obj_org = tkd.tkd_promptdata1 
      and    obj_code = tkd.tkd_promptdata2
      and    (nvl(OBJ_XCOORDINATE,0) <> nvl(xLoc,0)
      or nvl(OBJ_YCOORDINATE,0) <> nvl(yLoc,0));

     exception when err_val then
        RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
     end;
         
     --delete from r5trackingdata where rowid=:rowid;
     o7interface.trkdel(tkd.tkd_transid);
  end if;
  
exception
  when no_data_found then 
    null;
  when others then 
     RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5trackingdata/Insert/40/' ||SQLCODE || SQLERRM) ;
end;