DECLARE
	vCount			NUMBER;
	vComm				LONG;
	vAddCode    r5addetails.add_code%type; 
	vOrg        r5organization.org_code%type;
BEGIN
  SELECT r5parts.par_desc, r5rfqlines.rli_rfq || '#' || r5rfqlines.rli_org || '#' || r5rfqlines.rli_rfqline, r5rfqlines.rli_org 
  INTO vComm, vAddCode, vOrg
  FROM r5rfqlines, r5parts
  WHERE r5rfqlines.rli_part = r5parts.par_code
	AND rli_part_org = par_org AND r5rfqlines.rowid =:rowid;
		
  SELECT COUNT(1) INTO vCount FROM r5addetails
  WHERE add_entity ='RFQL' AND add_type ='*' AND add_code = vAddCode;
  IF  vCount = 0 THEN
	
		INSERT INTO r5addetails(
          ADD_ENTITY,
          ADD_RENTITY,
          ADD_TYPE,
          ADD_RTYPE,
          ADD_CODE,
          ADD_LANG,
          ADD_LINE,
          ADD_PRINT,
          ADD_TEXT,
          ADD_CREATED,
          ADD_USER)
			VALUES(
          'RFQL',
          'RFQL',
          '*',
          '*',
          vAddCode,
          'EN',
          1,
          '+',
          vComm,
          o7gttime(vOrg),
          O7SESS.CUR_USER);
    END IF;
END;