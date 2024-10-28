declare 
 ivl              r5invoicelines%rowtype;
 vSourceSystem    r5invoices.inv_sourcesystem%type;
 vSourceCode      r5invoices.inv_sourcecode%type;
 vSAPTax          r5invoices.inv_udfchar19%type;
 vSAPTaxAmount    number;
 vSAPTaxBaseAmount number;
 vInvType          r5invoices.inv_type%type;
 vInvReturn        r5invoices.inv_return%type;
 
 vEAMTaxCode        r5taxes.tax_code%type;
 vPurOrg            r5organization.org_udfchar06%type;
 
 vReceiptRef       r5invoicelines.ivl_udfchar23%type;
 vExtra            r5invoicelines.ivl_totextra%type;
 vPrice            r5invoicelines.ivl_price%type;
 vQuantity         r5invoicelines.ivl_invqty%type;
 vValue            r5invoicelines.ivl_invvalue%type;
 vReturnQty        r5invoicelines.ivl_returnqty%type;
 vTaxamount        r5invoicelines.ivl_tottaxamount%type;
 vTaxDetailLvlCnt   number;
 
 vOrlRecvQty        r5orderlines.orl_recvqty%type;
 vOrlMultiply       r5orderlines.orl_multiply%type;
 vInvoicedQty       r5invoicelines.ivl_invqty%type;
 vIvlMatched         r5invoicelines.ivl_matched%type;

 iErrMsg           varchar2(400);
 err_val           exception;
 
 cursor cur_tax (vSAPTaxAll in varchar2,vSpilt in varchar2) is
 select regexp_substr(vSAPTaxAll,'[^'||vSpilt||']+', 1, level) as seg_tax,level as seg_tax_level from dual
 connect by regexp_substr(vSAPTaxAll, '[^'||vSpilt||']+', 1, level) is not null
 order by level;
 
 cursor cur_taxDetails (vSAPTax in varchar2,vSpilt in varchar2) is
 select regexp_substr(vSAPTax,'[^'||vSpilt||']+', 1, level) as seg_taxdetails,level as seg_taxdetails_level  from dual
 connect by regexp_substr(vSAPTax, '[^'||vSpilt||']+', 1, level) is not null
 order by level;
 
 function u5preinvmtch (
  ord VARCHAR2,
  org VARCHAR2,
  lin NUMBER,
  ivlin NUMBER ) RETURN  VARCHAR2 IS
  vMatch varchar2(1);

  CURSOR ivl IS
  SELECT l.ivl_invoice, l.ivl_invoice_org, l.ivl_invline,
         i.inv_supplier, i.inv_supplier_org, i.inv_prematchuser,
         DECODE( o.orl_rtype,
                 'SF', o.orl_recvvalue - NVL( o.orl_invvalue, 0 ),
                       ( o.orl_recvqty - NVL( o.orl_invqty, 0 ) ) /
                         NVL( o.orl_multiply, 1 ) ) qtyopen,
         DECODE( o.orl_rtype,
                 'SF', l.ivl_price, l.ivl_invqty ) qtyinv
  FROM   r5invoices i,
         r5orderlines o,
         r5invoicelines l
  WHERE  i.inv_code      = l.ivl_invoice
  AND    i.inv_org       = l.ivl_invoice_org
  AND    l.ivl_order     = o.orl_order
  AND    l.ivl_order_org = o.orl_order_org
  AND    l.ivl_ordline   = o.orl_ordline
  --AND    i.inv_rstatus   = 'PM'
  AND    l.ivl_order     = ord
  AND    l.ivl_order_org = org
  AND    l.ivl_ordline   = lin
  and    nvl(l.ivl_matched,' ') not in ('M')
  --AND    l.ivl_invline = ivlin
  AND    I.INV_RSTATUS NOT IN ('C')-- ADD BY CXU FOR SAP INTEERFACE
  ORDER  BY i.inv_date;

  CURSOR ivl2 ( curord VARCHAR2, curorg VARCHAR2, curline NUMBER ) IS
  SELECT NVL( SUM( DECODE( l.ivl_rtype, 'SF', l.ivl_price, l.ivl_invqty ) ), 0 )
  FROM   r5invoices i,
         r5invoicelines l
  WHERE  i.inv_code      = l.ivl_invoice
  AND    i.inv_org       = l.ivl_invoice_org
  --AND    i.inv_rstatus   = 'M'
  AND    l.ivl_order     = curord
  AND    l.ivl_order_org = curorg
  AND    l.ivl_ordline   = curline
  and    i.inv_rstatus not in ('A')
  and    nvl(l.ivl_matched,' ') in ('M')
  AND    I.INV_RSTATUS NOT IN ('C');-- ADD BY CXU FOR SAP INTEERFACE;

  CURSOR ivl3 ( curinv VARCHAR2, curorg VARCHAR2 ) IS
  SELECT i.ivl_invvalue, i.ivl_order, i.ivl_ordline, i.ivl_order_org,
         i.ivl_invqty, i.ivl_price, i.ivl_rtype, i.ivl_tottaxamount,
         i.ivl_totextra, o.orl_recvqty, o.orl_recvvalue, o.orl_price,
         o.orl_multiply, o.orl_ordqty, o.orl_invqty, o.orl_invvalue,
         ( NVL( h.ord_discperc, 0 ) + NVL( o.orl_discperc, 0 ) -
         ( NVL( h.ord_discperc, 0 ) * NVL( o.orl_discperc, 0 ) / 100 ) ) orl_disc,
         o.orl_totextra, i.ivl_invline
  FROM   r5orderlines o,
         r5orders h,
         r5invoicelines i
  WHERE  o.orl_order       = i.ivl_order
  AND    o.orl_ordline     = i.ivl_ordline
  AND    o.orl_order_org   = i.ivl_order_org
  AND    h.ord_code        = i.ivl_order
  AND    h.ord_org         = i.ivl_order_org
  AND    i.ivl_invoice     = curinv
  AND    i.ivl_invoice_org = curorg;

  qtymatched      NUMBER;
  matchlta        NUMBER;
  matchltp        NUMBER;
  invqtytol       NUMBER;
  chkamount       NUMBER;
  maxamount       NUMBER;
  minamount       NUMBER;
  orlmatch        NUMBER;
  ivlmatch        NUMBER;
  nowmatched      NUMBER := 0;
  status          r5invoices.inv_status%TYPE;
  rstatus         r5invoices.inv_rstatus%TYPE;
  matchhold       VARCHAR2( 1 ) :=  '-';
  matchholdline   VARCHAR2( 1 );
  chk             VARCHAR2( 4 );
  x               VARCHAR2( 100 );

BEGIN
  /* Loop through all invoice lines that are related to the received order line */
  FOR i IN ivl LOOP
    IF i.qtyopen - nowmatched >= i.qtyinv THEN
      /* Retrieve qty matched on other invoices */
      OPEN  ivl2( ord, org, lin );
      FETCH ivl2 INTO qtymatched;
      CLOSE ivl2;
      IF i.qtyopen - NVL( qtymatched , 0 ) - nowmatched >= i.qtyinv THEN


        /* First retrieve tolerances */
        SELECT org_matchlta,
               org_matchltp,
               org_invqtytol
        INTO   matchlta,
               matchltp,
               invqtytol
        FROM   r5organization
        WHERE  org_code = i.ivl_invoice_org;
        /* There is enough open to invoice, so */
        /* check all other lines on the invoice. */
        FOR j IN ivl3 ( i.ivl_invoice, i.ivl_invoice_org ) LOOP
          matchholdline := '-';
          /* Check no more invoiced than received */
          OPEN  ivl2(  j.ivl_order, j.ivl_order_org, j.ivl_ordline );
          FETCH ivl2 INTO qtymatched;
          CLOSE ivl2;
          IF ( ( ( j.ivl_invqty + NVL( qtymatched, 0 ) ) *
                   NVL( j.orl_multiply, 1 ) ) + NVL( j.orl_invqty, 0 ) >
               NVL( j.orl_recvqty, 0 ) AND j.ivl_rtype <> 'SF' ) OR
             ( j.ivl_invvalue + NVL( j.orl_invvalue, 0 ) + NVL( qtymatched, 0 ) >
               NVL( j.orl_recvvalue, 0 ) AND j.ivl_rtype = 'SF' ) THEN
            matchhold     := '+';
            matchholdline := 'O';
          END IF;
         orlmatch := j.orl_price * ( ( 100 - NVL( j.orl_disc, 0 ) ) / 100 ) +
                   ( NVL( j.orl_totextra, 0 ) / j.orl_ordqty / NVL( j.orl_multiply, 1 ) );
         ivlmatch := j.ivl_price +
                   ( NVL( j.ivl_totextra, 0 ) / j.ivl_invqty );
          IF matchlta IS NOT NULL AND
            j.ivl_rtype <> 'SF' AND
            matchholdline = '-' THEN
            /* Check absolute tolerance */
            minamount := GREATEST( orlmatch - matchlta, 0 );
            maxamount := orlmatch + matchlta;
            IF ivlmatch NOT BETWEEN minamount AND maxamount THEN
              /* Something wrong, set variables accordingly */
              matchhold     := '+';
              matchholdline := '+';
            END IF;
          END IF;
          IF matchltp IS NOT NULL AND
            j.ivl_rtype <> 'SF' AND
            matchholdline = '-' THEN
            /* Check percentage tolerance */
            minamount := GREATEST( orlmatch - ( orlmatch * matchltp / 100 ), 0 );
            maxamount := orlmatch + ( orlmatch * matchltp / 100 );
            IF ivlmatch NOT BETWEEN minamount AND maxamount THEN
              matchhold     := '+';
              matchholdline := '+';
            END IF;
          END IF;
          IF invqtytol IS NOT NULL AND
            matchholdline = '-' THEN
            /* Check qty tolerance */
            IF j.ivl_rtype = 'SF' THEN
              maxamount := j.orl_price + ( j.orl_price * invqtytol / 100 );
              chkamount := j.ivl_price + NVL( j.orl_invvalue, 0 );
            ELSE
              maxamount := j.orl_ordqty + ( j.orl_ordqty * invqtytol / 100 );
              chkamount := ( j.ivl_invqty * NVL( j.orl_multiply, 1 ) ) +
                           NVL( j.orl_invqty, 0 );
            END IF;
            IF chkamount > maxamount THEN
              matchhold     := '+';
              matchholdline := '+';
            END IF;
          END IF;
          /* Update invoice line with result of check.*/

          SELECT DECODE( matchholdline, 'O', 'O', '-', 'M', 'H' ) INTO vMatch
          FROM r5invoicelines
          WHERE  ivl_invoice     = i.ivl_invoice
          AND    ivl_invoice_org = i.ivl_invoice_org
          AND    ivl_invline     = j.ivl_invline;

        END LOOP;
        IF matchhold = '-' and 1 = 2 THEN
          /* Whole invoice can be set to 'Matched' */
          rstatus := 'M';
          IF UPPER( o7dflt( 'MATCHAPP', chk ) ) = 'YES' AND
            i.inv_prematchuser IS NOT NULL THEN
            /* Invoice can even be approved */
            rstatus := 'A';
          END IF;
          status := r5o7.o7ucode( rstatus, 'IVST', chk );
          /* match or approve invoice */
          UPDATE r5invoices
          SET    inv_rstatus = rstatus,
                 inv_status  = status,
                 inv_auth    = DECODE( rstatus, 'A', i.inv_prematchuser, '' )
          WHERE  inv_code    = i.ivl_invoice
          AND    inv_org     = i.ivl_invoice_org;
          IF rstatus = 'A' THEN
            /* Do updates of order line data and prices. */
            o7upired( i.ivl_invoice, i.ivl_invoice_org, 'I', rstatus, chk );
            o7upinv1( i.ivl_invoice, i.ivl_invoice_org, x, 'I', status, rstatus,
                      'PM', i.inv_supplier, i.inv_supplier_org, i.inv_prematchuser, chk );
            nowmatched := nowmatched + i.qtyinv;
          END IF;
        END IF;
      ELSE
        /* Still over invoiced, update invoice line accordingly.*/
        vMatch := 'O';
      END IF;
    ELSE
      /* Still over invoiced, update invoice line accordingly.*/
      vMatch := 'O';
    END IF;
  END LOOP;
  return vMatch;
END u5preinvmtch;

 
begin
  select * into ivl from r5invoicelines where rowid=:rowid;--ivl_invoice = '100017' and ivl_invoice_org = 'BAR';
  select inv_sourcesystem,inv_sourcecode, inv_udfchar19,i.inv_type,i.inv_return 
  into vSourceSystem,vSourceCode,vSAPTax,vInvType,vInvReturn
  from r5invoices i
  where inv_code = ivl.ivl_invoice and inv_org = ivl.ivl_invoice_org;
  
  
    
  if vSourceSystem = 'SAP' then
     begin
        if ivl.ivl_type like 'P%' then
           select trl_dckcode into vReceiptRef
           from r5translines
           where trl_trans = to_number(ivl.ivl_udfchar25) and trl_line =  to_number(ivl.ivl_udfchar24)
           and   trl_order = ivl.ivl_order and trl_ordline = ivl.ivl_ordline and trl_order_org = ivl.ivl_order_org;
        else
          select boo_event into vReceiptRef
          from r5bookedhours,r5activities,r5orderlines
          where boo_event = act_event and boo_act = act_act
          and   orl_order = nvl(boo_order,act_order) and orl_ordline = nvl(boo_ordline,act_ordline)
          and   orl_order = ivl.ivl_order and orl_ordline = ivl.ivl_ordline and orl_order_org = ivl.ivl_order_org
          and   boo_code = to_number(ivl.ivl_udfchar25);
        end if;
      exception when no_data_found then
         iErrMsg := 'Receipt Not found for '|| ivl.ivl_udfchar25 ||'#'||ivl.ivl_udfchar24;
         raise err_val;
      when others then
         iErrMsg := 'Invalid Receipt for '|| ivl.ivl_udfchar25 ||'#'||ivl.ivl_udfchar24;
         raise err_val;
      end;
  
     if vInvType = 'I' or (vInvType = 'C' and vInvReturn = '+') then
        if ivl.ivl_type ='SF' then
          --For sf get extral value
          /*****Amend by CXU on 201803 to fix bug for extra discount*******
          if rline.Subtotal - rline.quantity > 0 then
          -->
          if rline.Subtotal - rline.quantity <> 0 then
          *****************************************************************/
          if (nvl(ivl.ivl_udfnum01,0) - nvl(ivl.ivl_udfnum02,0))<> 0 then
             vExtra :=  nvl(ivl.ivl_udfnum01,0) - nvl(ivl.ivl_udfnum02,0);
          end if;
          --vLineSubTtoal := ivl.ivl_udfnum02;
          vPrice := ivl.ivl_udfnum02;
          vQuantity := 1;
        else
          if nvl(ivl.ivl_udfnum02,0) <> 0 then
             vPrice := nvl(ivl.ivl_udfnum01,0)/nvl(ivl.ivl_udfnum02,0);
          else
             vPrice := 0;
          end if;
          vQuantity := ivl.ivl_udfnum02;
        end if;
      else
        vPrice := nvl(ivl.ivl_udfnum01,0);
        vQuantity := 1;
      end if;
      vReturnQty := 0;
      vValue := vQuantity *  vPrice;
      if vInvType = 'C' and vInvReturn = '+' then
         vReturnQty := vQuantity;
         vQuantity := 1;
         vValue := vReturnQty *  vPrice;
      end if;
      
      --loop for udfchar19 go get taxamount
      if nvl(vSAPTax,' ') <> ' ' then
        for rec_tax in cur_tax(vSAPTax,'#') loop
              -- get eam tax code
              select org_udfchar06 into vPurOrg from r5organization where org_code = ivl.ivl_invoice_org;  
              vEAMTaxCode := replace(ivl.ivl_tax,vPurOrg||'-',null);
            
              if instr(rec_tax.seg_tax,vEAMTaxCode) > 0 then
                  --validate sap tax information is completed? should have 3 level
                  select count(1) into vTaxDetailLvlCnt
                  from (
                   select regexp_substr(rec_tax.seg_tax,'[^'||':'||']+', 1, level) as seg_taxdetails  from dual
                   connect by regexp_substr(rec_tax.seg_tax, '[^'||':'||']+', 1, level) is not null
                  );
                  if vTaxDetailLvlCnt < 3 then 
                     iErrMsg := 'Missing SAP Tax Information. Please check with Admin.';
                     raise err_val;
                  end if;
                    
                  --loop for sap invoice tax information to get amount and calculae extra charge
                 for rec_taxdetails in cur_taxDetails(rec_tax.seg_tax,':') loop
                     if rec_taxdetails.seg_taxdetails_level = 2 then
                        vSAPTaxAmount := to_number(rec_taxdetails.seg_taxdetails);
                     end if;
                     if rec_taxdetails.seg_taxdetails_level = 3 then
                        vSAPTaxBaseAmount := to_number(rec_taxdetails.seg_taxdetails);
                     end if; 
                 end loop;
                   
              end if;
          end loop;
      else
          iErrMsg := 'Missing SAP Tax Information. Please check with Admin.';
          raise err_val;
      end if;
      
      if vSAPTaxAmount = 0 then
          vTaxamount := 0;
      else
          vTaxamount:=round(nvl(ivl.ivl_udfnum01,0)/vSAPTaxBaseAmount*vSAPTaxAmount,3);
      end if;
      
      
      if nvl(vExtra,0) <> 0 then
          delete from r5extcharges 
          where ech_invord_code = ivl.ivl_invoice and ech_invord_org = ivl.ivl_invoice_org
          and ech_code = 10;
      
          insert into r5extcharges
          (ech_code,
          ech_type,
          ech_rtype,
          ech_discount,
          ech_invord_code,
          ech_invord_org,
          ech_invord_line,
          ech_invord,
          ech_parprice,
          ech_cumulative
          )
          values
          ('10',
           'PRT',--'POT',
           'PRT',--'POT',
           ivl.ivl_udfnum01,
           ivl.ivl_invoice,
           ivl.ivl_invoice_org,
           ivl.ivl_invline,
           'I',
           '+',
           '+'
          );
      end if;
      
      
      update r5invoicelines 
      set 
      ivl_invqty = nvl(vQuantity,0),
      ivl_returnqty = nvl(vReturnQty,0),
      ivl_price = nvl(vPrice,0),
      ivl_totextra = nvl(vExtra,0),
      ivl_tottaxamount = nvl(vTaxamount,0),
      ivl_invvalue =  nvl(vValue,0),
      ivl_sourcesystem = vSourceSystem,
      ivl_sourcecode = vSourceCode,
      ivl_interface = o7gttime(ivl_invoice_org),
      ivl_udfchar23 = vReceiptRef
      where rowid=:rowid;
      
      if vInvType = 'I' then
        --vIvlMatched := u5preinvmtch(ivl.ivl_order,ivl.ivl_order_org,ivl.ivl_ordline,ivl.ivl_invline);
        --vIvlMatched := 'M';
        select nvl(case when orl_type ='SF' then o.orl_recvvalue else o.orl_recvqty end,0),o.orl_multiply
        into vOrlRecvQty,vOrlMultiply
        from r5orderlines o where orl_order = ivl.ivl_order and orl_ordline = ivl.ivl_ordline and orl_order_org = ivl.ivl_order_org;
       
        select nvl(sum(ivl_invqty)-sum(ivl_returnqty),0) into vInvoicedQty
        from (select 
        case when inv_type ='I' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_invqty),0) else 0 end as ivl_invqty,
        case when inv_type ='C' and inv_return ='+' and inv_status ='A' then 
        nvl(decode(ivl_type,'SF',ivl_invvalue,ivl_returnqty),0) else 0 end as ivl_returnqty
        from   r5invoices,r5invoicelines
        where  inv_code = ivl_invoice and inv_org =ivl_invoice_org
        --and    inv_type = 'I' 
        and inv_status  not in ('C')
        and    ivl_order = ivl.ivl_order and ivl_ordline =ivl.ivl_ordline
        and    ivl_order_org = ivl.ivl_order_org
        );
        
        vIvlMatched := 'M';
        --if vInvoicedQty + vQuantity > vOrlRecvQty/nvl(vOrlMultiply,1) then
        if vInvoicedQty > vOrlRecvQty/nvl(vOrlMultiply,1) then
           vIvlMatched := 'O';
        end if;
        
        if vIvlMatched not in ('M') then
           iErrMsg := 'Line: '|| ivl.ivl_invline || 'cannot invoice more than received. InvoiceQty:'||vInvoicedQty ||'/CurrQty:'||vQuantity||'/RecvQty:'||vOrlRecvQty/nvl(vOrlMultiply,1);
           raise err_val;
        else
           update r5invoicelines
           set    ivl_matched     = vIvlMatched
           where rowid=:rowid;
        end if;
      end if;
  end if;
  
exception 
  when err_val then
     RAISE_APPLICATION_ERROR ( -20003,iErrMsg) ;
  when others then 
      RAISE_APPLICATION_ERROR ( -20003, 'Processing error in Flex/r5invoicelines/Insert/30' ||SQLCODE || SQLERRM) ;
end;
