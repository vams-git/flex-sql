declare 
  inv              r5invoices%rowtype;
 
  
begin
  select * into inv from r5invoices where rowid=:rowid;
  if inv.inv_rstatus  ='M' then
     /* Set evo_recalccost flag. */
      UPDATE u5vucost
      SET    evo_recalccost = '+', evo_costcalculated = '-'
      WHERE  evo_event IN (
        SELECT orl_event
        FROM   r5orderlines, r5invoicelines
        WHERE  orl_order = ivl_order
        AND    orl_order_org = ivl_order_org
        AND    orl_ordline = ivl_ordline
        AND    ivl_invoice = inv.inv_code )
      AND    NVL( evo_recalccost, '-' ) <> '+';
      
      UPDATE u5vucost
      SET    evo_recalccost = '+', evo_costcalculated = '-'
      WHERE  evo_parent IN (
        SELECT orl_event
        FROM   r5orderlines, r5invoicelines
        WHERE  orl_order = ivl_order
        AND    orl_order_org = ivl_order_org
        AND    orl_ordline = ivl_ordline
        AND    ivl_invoice = inv.inv_code )
      AND    NVL( evo_recalccost, '-' ) <> '+';
      
      UPDATE u5vucost
      SET    evo_recalccost = '+', evo_costcalculated = '-'
      WHERE  evo_event IN (
        SELECT distinct boo_event
        from   r5bookedhours,r5orderlines, r5invoicelines
        WHERE  boo_order = orl_order and boo_ordline = orl_ordline
        and    orl_order = ivl_order and orl_order_org = ivl_order_org and orl_ordline = ivl_ordline 
        and    orl_type ='SH'
        and    ivl_invoice = inv.inv_code and ivl_invoice_org = inv.inv_org )
      AND    NVL( evo_recalccost, '-' ) <> '+';
      
      UPDATE u5vucost
      SET    evo_recalccost = '+', evo_costcalculated = '-'
      WHERE  evo_parent IN (
        SELECT distinct boo_event
        from   r5bookedhours,r5orderlines, r5invoicelines
        WHERE  boo_order = orl_order and boo_ordline = orl_ordline
        and    orl_order = ivl_order and orl_order_org = ivl_order_org and orl_ordline = ivl_ordline 
        and    orl_type ='SH'
        and    ivl_invoice = inv.inv_code and ivl_invoice_org = inv.inv_org)
      AND    NVL( evo_recalccost, '-' ) <> '+';
  end if;
      


exception
/*when errValidate then
RAISE_APPLICATION_ERROR (-20001,iErrMsg);   */
when others then
RAISE_APPLICATION_ERROR (-20001,'Error in Flex R5INVOICES/Post Update/210/'||substr(SQLERRM, 1, 500)); 
end;