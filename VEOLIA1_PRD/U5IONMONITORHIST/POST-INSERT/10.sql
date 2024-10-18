declare 
  ion      u5ionmonitorhist%rowtype;
  vDebit   r5glinterfacehist%rowtype;
  vCredit  r5glinterfacehist%rowtype;
  vmail    r5mailtemplate.mat_code%type;
  vVamsDetails  varchar2(80);         
  vCnt     number;
  vMaxCost number;
begin
  vMaxCost := 500000;
  vmail := 'M-AUS-SAPINF-GL';
  select * into ion from u5ionmonitorhist where rowid=:rowid;
  if ion.ion_status = 'S' and ion.ion_trans = 'GL' then
     select count(1) into vCnt from r5glinterfacehist 
     where glh_runid = ion.ion_keyfld1 
     and  (glh_enteredcr >= vMaxCost or glh_entereddr >= vMaxCost) ;
     if vCnt > 0 then
        select * into vDebit from r5glinterfacehist
        where glh_runid = ion.ion_keyfld1 
        and glh_entereddr >= vMaxCost;
        
        select * into vCredit from r5glinterfacehist
        where glh_runid = ion.ion_keyfld1 
        and glh_enteredcr >= vMaxCost;
        
        if instr(vDebit.Glh_Attribute2,'-') > 0 then
           select tra_org ||' - ' ||trl_part into vVamsDetails
           from   r5transactions,r5translines
           where  tra_code = trl_trans 
           and    trl_trans ||'-'||trl_line = vDebit.Glh_Attribute2;
        else
           select evt_org ||' - ' || evt_code into vVamsDetails
           from   r5events,r5bookedhours 
           where  evt_code = boo_event 
           and    boo_code = vDebit.Glh_Attribute2;
        end if;
        
        insert into r5mailevents
        (MAE_CODE,MAE_TEMPLATE,MAE_DATE,MAE_SEND,MAE_RSTATUS,MAE_ATTRIBPK,
         MAE_PARAM1,MAE_PARAM2,MAE_PARAM3,MAE_PARAM4,MAE_PARAM5,
         MAE_PARAM6,MAE_PARAM7,MAE_PARAM8,MAE_PARAM9,
         MAE_PARAM10,MAE_PARAM11,MAE_PARAM12,MAE_PARAM13
        )
        values
        (S5MAILEVENT.NEXTVAL,vmail,SYSDATE,'-','N',0,
         ion.ion_transid,to_char(ion.ion_update,'DD-MON-YYYY HH24:MI:SS'),vDebit.Glh_Attribute2,vVamsDetails,abs(vDebit.Glh_Entereddr),
         vDebit.Glh_Segment1,vDebit.Glh_Segment2,vDebit.Glh_Segment3,vDebit.Glh_Segment4,
         vCredit.Glh_Segment1,vCredit.Glh_Segment2,vCredit.Glh_Segment3,vCredit.Glh_Segment4
        );
     end if; 
  end if;
exception when others then 
  return;
end;