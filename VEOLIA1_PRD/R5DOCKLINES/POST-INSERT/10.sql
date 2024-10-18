declare 
  dkl            r5docklines%rowtype;
  
  vOrlComment    varchar2(80);
  vSAPItemCode   r5parts.par_udfchar20%type;
  vPartDesc      r5parts.par_udfchar24%type;
  vOrlPurUOM     r5orderlines.orl_puruom%type;
  vDelAddress    r5orderlines.orl_deladdress%type;
  vRecvDate      r5dockreceipts.dck_recvdate%type;
  vSAPUOM        r5orderlines.orl_puruom%type;
  vOrdStore      r5stores.str_code%type;
  vOrg           r5organization.org_Code%type;
  vParClass      r5parts.par_class%type;
  vDepCode       r5depots.dep_code%type;
  vTanCode	     r5tanks.tan_code%type;
  vFuelCode      r5fuels.fue_code%type;
begin
  select * into dkl from r5docklines where rowid=:rowid;
  
  if dkl.dkl_order is not null then
     select 
     case when orl_type in ('SF','ST') then dbms_lob.substr(R5REP.TRIMHTML(orl_event||'#'||orl_act,'EVNT','*','EN',10),80,1)
     else dbms_lob.substr(R5REP.TRIMHTML(orl_order||'#'||orl_order_org||'#'||orl_ordline,'PORL','*','EN',10),80,1) end
     ,par_udfchar24,par_udfchar20,orl_deladdress, orl_puruom,
     ord_store,ord_org,par_class
     into vOrlComment
     ,vPartDesc,vSAPItemCode,vDelAddress,vOrlPurUOM
     ,vOrdStore,vOrg,vParClass
     from r5orders,r5orderlines,r5parts 
     where ord_code = orl_order and ord_org = orl_order_org
     and   orl_part = par_code and orl_part_org = par_org
     and   orl_order_org = dkl.dkl_order_org and orl_order = dkl.dkl_order
     and   orl_ordline = dkl.dkl_ordline;
     
     select dck_recvdate into vRecvDate
     from r5dockreceipts
     where dck_code = dkl.dkl_dckcode;
     
     begin
       select Sum_Sapinternalcode into vSAPUOM
       from u5sapuom,r5uoms
       where sum_uom = uom_code and uom_notused ='-'
       and sum_uom =  vOrlPurUOM
       and Sum_Sapinternalcode is not null
       and rownum <= 1;
     exception when no_data_found then
       vSAPUOM := vOrlPurUOM;
     end;
     
     update r5docklines
     set 
     dkl_udfdate01 = vRecvDate,
     dkl_udfchar06 = vSAPItemCode,
     dkl_udfchar07 = vPartDesc,
     dkl_udfchar08 = vSAPUOM,
     dkl_udfchar09 = vDelAddress
     where dkl_dckcode = dkl.dkl_dckcode and dkl_line = dkl.dkl_line;
     
     
     if vOrlComment is not null then
        update r5docklines 
        set dkl_udfchar01 = vOrlComment
        where dkl_dckcode = dkl.dkl_dckcode and dkl_line = dkl.dkl_line
        and   nvl(dkl_udfchar01,' ')<> nvl(vOrlComment,' ');
     end if;
     
     if vParClass IN ('FUEL','ADBLUE') then
        begin
          select dep_code into vDepCode
          from r5depots where dep_org = vOrg and dep_udfchar01 = vOrdStore
          and rownum <=1;
          update r5docklines 
          set dkl_udfchar11 = vDepCode
          where dkl_dckcode = dkl.dkl_dckcode and dkl_line = dkl.dkl_line
          and   nvl(dkl_udfchar11,' ')<> nvl(vDepCode,' ');
		  
		  if vDepCode is not null then
		     begin 
			    select tan_code,tan_fuel
				into vTanCode,vFuelCode
				from r5tanks,r5fuels
				where tan_depot = vDepCode and tan_depot_org = vOrg
			    and   tan_fuel = fue_code
			    and   fue_udfchar02 = dkl.dkl_part;
				
				update r5docklines 
                set dkl_udfchar12 = vTanCode,dkl_udfchar13 = vFuelCode	
                where dkl_dckcode = dkl.dkl_dckcode and dkl_line = dkl.dkl_line
                and   (nvl(dkl_udfchar12,' ')<> nvl(vTanCode,' ')
				  or   nvl(dkl_udfchar13,' ')<> nvl(vFuelCode,' ')
				  );
			 exception when others then	   
			   null;
			 end;
		 end if;
		 
        exception when no_data_found then
          null;
        end;
			
     end if;
     
     --select par_udfchar24
       
  end if;
  
exception 
when others then
 RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5DOCKLINES/Post Insert/10') ;
  --RAISE_APPLICATION_ERROR ( SQLCODE,substr(SQLERRM, 1, 500)) ; 
end;