declare
   vi_addtext  VARCHAR2(4000);
   vi_lotoflag r5events.evt_udfchkbox05%type;
   vi_evtcode  r5events.evt_code%type;
   vi_addentity r5addetails.add_entity%type;
   vi_addtype   r5addetails.add_type%type;
   vi_addcode r5addetails.add_code%type;
   vi_addline r5addetails.add_line%type;
   
begin
   select ad1.add_entity,ad1.add_type, ad1.add_code,ad1.add_line
   into   vi_addentity,  vi_addtype, vi_addcode,vi_addline
   from   r5addetails ad1
   where  ad1.rowid=:rowid;
   
   if vi_addentity = 'EVNT' and instr(vi_addcode,'#') > 0 Then
     vi_lotoflag := '-';
     vi_addtext  := dbms_lob.substr(R5REP.TRIMHTML(vi_addcode,vi_addentity,vi_addtype,'EN',vi_addline),3500,1);
     if instr(vi_addtext,'LOTO') >  0 Then
        vi_lotoflag := '+';
     end if;
     
     update r5activities
     set    act_udfchkbox05= vi_lotoflag
     where  act_event || '#' || act_act = vi_addcode
     and    act_udfchkbox05<> vi_lotoflag;
   
   end if;
end;