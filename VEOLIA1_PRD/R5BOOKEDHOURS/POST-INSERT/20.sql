SELECT 1 FROM R5EVENTS EVT , R5BOOKEDHOURS BOO , R5ORGANIZATION ORG 
WHERE  EVT.EVT_CODE = BOO.BOO_EVENT 
AND       EVT.EVT_STATUS IN ( 'C', '55CA' ) 
AND       BOO.BOO_UDFCHAR02 IS NULL
AND       EVT.EVT_ORG = ORG.ORG_CODE   
AND       BOO.ROWID =:ROWID 