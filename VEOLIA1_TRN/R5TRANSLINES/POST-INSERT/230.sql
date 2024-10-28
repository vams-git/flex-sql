declare
  trl             r5translines%rowtype; 
  IPAR_WBS R5TRANSLINES.TRL_UDFCHAR24%TYPE;

begin
 select * into trl from r5translines where rowid=:rowid;
 update r5translines
 set trl_jecategory ='RFBU',
 trl_jesource = 'GAMA'
 where rowid = :rowid
 and (trl_jecategory is null or trl_jesource is null);
 
 if trl.trl_rtype = 'I' and trl.trl_event is not null then
   BEGIN
      SELECT PAR_UDFCHAR22
      INTO IPAR_WBS
      FROM R5PARTS
      WHERE PAR_CODE = TRL.TRL_PART
      AND PAR_ORG = TRL.TRL_PART_ORG
      AND PAR_TOOL IS NOT NULL ;
   EXCEPTION WHEN OTHERS THEN
      IPAR_WBS := NULL;
   END;
   update r5translines
   set TRL_UDFCHAR24 =IPAR_WBS
   where rowid = :rowid
   and NVL(TRL_UDFCHAR24, ' ') <> NVL(IPAR_WBS,' ');
  
 end if;

exception 
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5TRANSLINES/Post Insert/230' ||SQLCODE || SQLERRM);
end;
