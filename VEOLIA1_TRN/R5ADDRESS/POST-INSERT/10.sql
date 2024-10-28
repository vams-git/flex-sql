declare 
  adr          r5address%rowtype;
  vAdrText     r5address.adr_text%type;
  vAdraddress2 r5address.adr_address2%type;
  vContact     r5companies.com_contact%type;
begin
  select * into adr from r5address where rowid=:rowid;
  if adr.adr_rentity in ('COMP') then
       select
       DECODE(trim(adr.adr_city),NULL,NULL,trim(adr.adr_city)||', ')
        ||DECODE(trim(adr.adr_state),NULL,NULL,trim(adr.adr_state)||' ')
        ||DECODE(trim(adr.adr_zip),NULL,NULL,trim(adr.adr_zip))
       into vAdraddress2
       from dual;
       
      select
      DECODE(trim(adr.adr_address1),NULL,NULL,trim(adr.adr_address1)||CHR(10))
      ||DECODE(trim(adr.adr_address2),NULL,NULL,trim(adr.adr_address2)||CHR(10))
      ||DECODE(trim(adr.adr_address3),NULL,NULL,trim(adr.adr_address3)||CHR(10))
      ||DECODE(trim(adr.adr_country),null,null,trim(adr.adr_country))
      into
      vAdrText
      from dual;
      
      if nvl(adr.adr_address2,' ') <> nvl(vAdraddress2,' ') or nvl(adr.adr_text, ' ') <> nvl(vAdrText,' ') then
         update r5address
         set adr_address2 = vAdraddress2,
         adr_text = vAdrText
         where rowid=:rowid;
      end if;
      
      if adr.adr_rtype ='D' then
        select
        substr(
        DECODE(trim(adr.adr_address1),NULL,NULL,trim(adr.adr_address1)||' ')
        ||DECODE(trim(adr.adr_address2),NULL,NULL,trim(adr.adr_address2)||' ')
        ||DECODE(trim(adr.adr_address3),NULL,NULL,trim(adr.adr_address3)||' ')
        ||DECODE(trim(adr.adr_country),null,null,trim(adr.adr_country)),1,45)  
        into vContact from dual;
        
        update r5companies
        set com_contact = vContact
        where com_code||'#'||com_org = adr.adr_code 
        and nvl(com_contact,' ') <> vContact;
      end if;
      
  end if;

exception when others then 
    RAISE_APPLICATION_ERROR (-20001,'Error in Flex r5address/Post Insert/10' ||SQLCODE || SQLERRM);
end;