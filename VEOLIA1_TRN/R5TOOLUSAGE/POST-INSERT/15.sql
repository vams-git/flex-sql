SELECT 1 FROM R5EVENTS EVT , R5ACTIVITIES ACT,R5TOOLUSAGE TOU , R5ORGANIZATION ORG 
WHERE  EVT.EVT_CODE = ACT.ACT_EVENT
AND    ACT.ACT_EVENT=TOU.TOU_EVENT AND ACT.ACT_ACT=TOU.TOU_ACT
AND    ACT.ACT_HIRE='-' AND ACT.ACT_TASK IS NOT NULL
AND    EVT.EVT_ORG = ORG.ORG_CODE 
AND    ORG.ORG_LOCALE = 'NZ'  
AND    ((EVT.EVT_ORG NOT IN ('WCC','WBP') AND EVT.EVT_CLASS IN ('BD','CO'))
         OR (EVT.EVT_ORG IN ('WBP') AND EVT.EVT_CLASS IN ('BD','CO','RN','PS'))
       )
AND     TOU.ROWID =:ROWID 