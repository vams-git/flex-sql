declare 
  dck                    r5dockreceipts%rowtype;
  vUser                  r5personnel.per_code%type;
  vUserName              r5personnel.per_desc%type;
  vPODesc                r5orders.ord_desc%type;
  vDckDesc               varchar2(200);
  vPOStore               r5orders.ord_store%type;
  vPOSupp                r5orders.ord_supplier%type;
  
  chk                varchar2(4);
  oLine              varchar2(80);
  iErrMsg            varchar2(400); 
  DB_ERROR           EXCEPTION;
begin
  select * into dck from r5dockreceipts where rowid=:rowid;
    --[?Receipt for PO? + PO Number + PO Description + Today?s date]
  if dck.dck_order is not null then
    select ord_desc,ord_store,ord_supplier
    into   vPODesc,vPOStore,vPOSupp
    from r5orders
    where ord_code =dck.dck_order
    and ord_org = dck.dck_order_org;
    vDckDesc := substr(to_char(sysdate,'DD-MM-YYYY') || ' Receipt for PO ' || dck.dck_order || ' ' || vPODesc,1,80);

    update r5dockreceipts
    set    dck_desc = vDckDesc
    where  rowid =:rowid
    and    nvl(dck_desc,' ') <> vDckDesc;
  end if;
  
  Begin
      SELECT per_code,per_desc
      into vUser,vUserName
      FROM   r5userorganization u, r5personnel p
      WHERE  p.per_notused = '-'
      AND    p.per_org  = u.uog_org
      AND    per_desc = (select usr_desc from r5users where usr_code = o7sess.cur_user)
      AND    ( u.uog_common = '+' OR u.uog_org = dck.dck_org )
      AND    ROWNUM = 1;

      if dck.dck_receiver is null then
        update r5dockreceipts
        set    dck_receiver = vUser
        where  rowid =:rowid
        and    nvl(dck_receiver,' ') <> vUser; 
      end if;
    Exception when no_data_found then
      vUser := null;
      vUserName := null;
    end;
    
    o7crpslp(dck.dck_code,chk,'-',null,null,'-',oLine);
      
     if chk <> '0' then
       begin
         SELECT ETV_TEXT into iErrMsg
         FROM R5ERRORTEXT WHERE ETV_SOURCE = 'O7CRPSLP' AND ETV_LANG ='EN' AND ETV_NUMBER = chk;
       exception when no_data_found then 
          iErrMsg:= 'Active lines insert fail!';
       end;
       raise DB_ERROR;
     end if;

exception 
WHEN DB_ERROR THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5dockreceipts/Post Insert/20/'||SQLCODE || SQLERRM) ;
end;