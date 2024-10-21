declare 
  mp                   u5nzkpimap%rowtype;
  rec_spb              r5serviceproblemcodes%rowtype;
  vTargetDesc          nvarchar2(200);
  vFlag                nvarchar2(1);
  
  iErrMsg              varchar2(400); 
  DB_ERROR             EXCEPTION;
begin
  select * into mp from u5nzkpimap where rowid=:rowid;
  
  if mp.map_spbcode is not null then
      vFlag := 'Y';
      begin 
       select * into rec_spb
       from   r5serviceproblemcodes
       where  --spb_org = :new.map_org and
           spb_code = mp.map_spbcode
       and rownum<=1;
      exception when no_data_found then
        vFlag :='N';
      end;
  end if;
  
  if vFlag ='Y' then
        if mp.map_isrespond ='+' then
           select mp.map_target||'% within '||rec_spb.spb_udfnum01 ||' '||
           (select udl_desc from r5userdefinedfieldlovvals where udl_rentity ='SVPB' and udl_field ='udfchar01' and 
           udl_code =rec_spb.spb_udfchar01)
           into vTargetDesc
           from dual;
           
           update u5nzkpimap
           set map_isfirstrepair = '-',
           map_isrestoration = '-',
           map_iscompleted = '-',
           map_kpivalue = 'SPB_UDFNUM01',
           map_kpiunit ='SPB_UDFCHAR01',
           map_kpidate ='EVT_UDFDATE05',
           map_wodate = 'EVT_START',
           map_targetdesc = vTargetDesc
           where rowid = :rowid
           and (
           nvl(map_isfirstrepair,' ') <> '-' or
           nvl(map_isrestoration,' ') <> '-' or
           nvl(map_iscompleted,' ') <> '-' or
           nvl(map_kpivalue,' ') <> 'SPB_UDFNUM01' or
           nvl(map_kpiunit,' ') <> 'SPB_UDFCHAR01' or
           nvl(map_kpidate,' ') <> 'EVT_UDFDATE05' or
           nvl(map_wodate,' ') <> 'EVT_START' or
           nvl(map_targetdesc,' ') <> vTargetDesc
           );
        end if;  
        
        if mp.map_isfirstrepair ='+' then
           select mp.map_target||'% within '||rec_spb.spb_tempfixturnaround ||' '||
           (select udl_desc from r5userdefinedfieldlovvals where udl_rentity ='SVPB' and udl_field ='udfchar01' and 
           udl_code =rec_spb.spb_tempturnaroundunit)
           into vTargetDesc
           from dual;

           update u5nzkpimap
           set map_isrespond ='-',
           map_isrestoration = '-',
           map_iscompleted = '-',
           map_kpivalue = 'SPB_TEMPFIXTURNAROUND',
           map_kpiunit ='SPB_TEMPTURNAROUNDUNIT',
           map_kpidate ='EVT_TFPROMISEDATE',
           map_wodate = 'EVT_UDFDATE02',
           map_targetdesc = vTargetDesc
           where rowid = :rowid
           and (
           nvl(map_isrespond,' ') <> '-' or
           nvl(map_isrestoration,' ') <> '-' or
           nvl(map_iscompleted,' ') <> '-' or
           nvl(map_kpivalue,' ') <> 'SPB_TEMPFIXTURNAROUND' or
           nvl(map_kpiunit,' ') <> 'SPB_TEMPTURNAROUNDUNIT' or
           nvl(map_kpidate,' ') <> 'EVT_TFPROMISEDATE' or
           nvl(map_wodate,' ') <> 'EVT_UDFDATE02' or
           nvl(map_targetdesc,' ') <> vTargetDesc
           );
        end if; 
        
        if mp.map_isrestoration ='+' then
           select mp.map_target||'% within '||rec_spb.spb_udfnum02 ||' '||
           (select udl_desc from r5userdefinedfieldlovvals where udl_rentity ='SVPB' and udl_field ='udfchar01' and 
           udl_code =rec_spb.spb_udfchar02)
           into vTargetDesc
           from dual;
           
           update u5nzkpimap
           set map_isrespond ='-',
           map_isfirstrepair = '-',
           map_iscompleted = '-',
           map_kpivalue = 'SPB_UDFNUM02',
           map_kpiunit = 'SPB_UDFCHAR02',
           map_kpidate = 'EVT_TFDATECOMPLETED',
           map_wodate = 'EVT_UDFDATE03',
           map_targetdesc = vTargetDesc
           where rowid = :rowid
           and (
           nvl(map_isrespond,' ') <> '-' or
           nvl(map_isfirstrepair,' ') <> '-' or
           nvl(map_iscompleted,' ') <> '-' or
           nvl(map_kpivalue,' ') <> 'SPB_UDFNUM02' or
           nvl(map_kpiunit,' ') <> 'SPB_UDFCHAR02' or
           nvl(map_kpidate,' ') <> 'EVT_TFDATECOMPLETED' or
           nvl(map_wodate,' ') <> 'EVT_UDFDATE03' or
           nvl(map_targetdesc,' ') <> vTargetDesc
           );
        end if; 
        
        if mp.map_iscompleted ='+' then
           select mp.map_target||'% within '||rec_spb.spb_permfixturnaround ||' '||
           (select udl_desc from r5userdefinedfieldlovvals where udl_rentity ='SVPB' and udl_field ='udfchar01' and 
           udl_code =rec_spb.spb_permturnaroundunit)
           into vTargetDesc
           from dual;
           update u5nzkpimap
           set map_isrespond ='-',
           map_isfirstrepair = '-',
           map_isrestoration = '-',
           map_kpivalue = 'SPB_PERMFIXTURNAROUND',
           map_kpiunit ='SPB_PERMTURNAROUNDUNIT',
           map_kpidate ='EVT_PFPROMISEDATE',
           map_wodate = 'EVT_COMPLETED',
           map_targetdesc = vTargetDesc
           where rowid = :rowid
           and (
           nvl(map_isrespond,' ') <> '-' or
           nvl(map_isfirstrepair,' ') <> '-' or
           nvl(map_isrestoration,' ') <> '-' or
           nvl(map_kpivalue,' ') <> 'SPB_PERMFIXTURNAROUND' or
           nvl(map_kpiunit,' ') <> 'SPB_PERMTURNAROUNDUNIT' or
           nvl(map_kpidate,' ') <> 'EVT_PFPROMISEDATE' or
           nvl(map_wodate,' ') <> 'EVT_COMPLETED' or
           nvl(map_targetdesc,' ') <> vTargetDesc
           );
        end if; 
    end if;
   

exception 
WHEN DB_ERROR THEN
 RAISE_APPLICATION_ERROR ( -20003, iErrMsg) ; 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex u5nzkpimap/Post Insert/10/'||SQLCODE || SQLERRM) ;
end;