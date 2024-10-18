declare 
 trl             r5translines%rowtype;
 vOrg            r5organization.org_code%type;
 vStrGrp         r5stores.str_pricecode%type;
 vStockSrcType   r5stores.str_udfchar01%type;
 vSrcSystem      r5transactions.tra_sourcesystem%type;
 vParTool        r5parts.par_tool%type;
 
 iErrMsg   varchar2(200);
 val_err   exception;
 
begin
  select * into trl from r5translines where rowid=:rowid;

  if trl.trl_type = 'I' and trl.trl_event is not null and trl.trl_store is not null 
    and trl.trl_io = -1 and trl.trl_routerec is null then
    begin
      select par_tool into vParTool
      from r5parts
       where par_code = trl.trl_part and par_org = trl.trl_part_org;
       if vParTool is not null then
          return;
       end if;  
    
      select str.str_pricecode,str.str_udfchar01,str_org
      into   vStrGrp,vStockSrcType,vOrg
      from   r5stores str
      where  str.str_code = trl.trl_store;
      
      if vStockSrcType like 'STOREGRP%' and vStrGrp is not null then
         if nvl(trl.trl_origqty,trl.trl_qty) > 0 then
            select tra_sourcesystem into vSrcSystem
            from r5transactions
            where tra_code = trl.trl_trans;
            if nvl(vSrcSystem,' ') <> 'VAMS_STOS' then
              iErrMsg := 'Can not issue part from selected store.';
              raise val_err;
            end if;
         end if;
         
          insert into U5TUSTSL
          (sts_org,sts_store,sts_part,sts_part_org,sts_trans,sts_line,
          sts_io,sts_qty,sts_price,sts_event,
          createdby,created,updatecount) 
          values
          (vOrg,trl.trl_store,trl.trl_part,trl.trl_part_org,trl.trl_trans,trl.trl_line,
          trl.trl_io,nvl(trl.trl_origqty,trl.trl_qty),trl.trl_price,trl.trl_event,
          o7sess.cur_user,sysdate,0);
      end if;
    exception when no_data_found then
      return;
    end;
  end if;
   
  
exception
when val_err then
RAISE_APPLICATION_ERROR (-20001,iErrMsg);
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5translines/Post Insert/50') ;  
end;