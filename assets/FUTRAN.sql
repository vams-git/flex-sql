SELECT trl_order_org                                         trl_order_org,
       trl_order                                             trl_order,
       trl_ordline                                           trl_ordline,
       rql_req                                               rql_req,
       rql_reqline                                           rql_reqline,
       trl_trans                                             trl_trans,
       trl_line                                              trl_line,
       trl_date                                              trl_date,
       trl_type                                              trl_type,
       trl_part                                              trl_part,
       r5o7.O7GET_DESC('EN', 'PART', trl_part, '', '')       trl_partdesc,
       trl_price                                             trl_price,
       trl_qty                                               trl_qty,
       trl_price * trl_qty                                   trl_value,
       trl_udfnum04                                          trl_udfnum04,
       trl_udfnum05                                          trl_udfnum05,
       orl_curr                                              orl_curr,
       orl_supplier                                          orl_supplier,
       r5o7.O7GET_DESC('EN', 'COMP', orl_supplier, '', '')   orl_suppdesc,
       tra_auth                                              tra_auth,
       trl_event                                             trl_event,
       r5o7.O7GET_DESC('EN', 'EVNT', trl_event, '', '')      trl_eventdesc,
       (SELECT obj_oemsite
        FROM   R5OBJECTS,
               R5EVENTS
        WHERE  obj_code = evt_object
               AND obj_org = evt_object_org
               AND evt_code = trl_event)                     obj_oemsite,
       trl_act                                               trl_act,
       trl_store                                             trl_store,
       r5o7.O7GET_DESC('EN', 'STOR', trl_store, '', '')      trl_storedesc,
       trl_bin                                               trl_bin,
       trl_lot                                               trl_lot,
       r5o7.O7GET_DESC('EN', 'UCOD', orl_type, 'PLTP', '')   orl_type,
       TO_CHAR(trl_io)                                       trl_io,
       trl_interface                                         trl_interface,
       trl_udfchar01                                         trl_udfchar01,
       trl_udfchar03                                         trl_udfchar03,
       trl_udfchar02                                         trl_udfchar02,
       trl_udfchar04                                         trl_udfchar04,
       trl_desc                                              trl_desc,
       trl_acd                                               trl_acd,
       orl_tax                                               orl_tax,
       r5o7.O7GET_DESC('EN', 'UCOD', orl_status, 'RLST', '') orl_statusdesc,
       r5o7.O7GET_DESC('EN', 'UCOD', ord_status, 'DOST', '') ord_statusdesc,
       orl_costcode                                          orl_costcode,
       orl_udfchar28                                         orl_udfchar28,
       CASE
         WHEN orl_type IN ( 'SF', 'ST' ) THEN dbms_lob.SUBSTR(
         r5rep.TRIMHTML(orl_event
                        ||'#'
                        ||orl_act, 'EVNT', '*', 'EN', 10), 3500, 1)
         ELSE
dbms_lob.SUBSTR(r5rep.TRIMHTML(orl_order
                               ||'#'
                               ||orl_order_org
                               ||'#'
                               ||orl_ordline, 'PORL', '*', 'EN', 10), 3500, 1)
END                                                   orl_comment,
ord_desc                                              ord_desc
FROM   R5ORDERS,
       R5ORDERLINES,
       R5REQUISLINES,
       (SELECT trl_order_org,
               trl_order,
               trl_ordline,
               trl_trans,
               trl_line,
               trl_udfdate01                                       AS trl_date,
               r5o7.O7GET_DESC('EN', 'UCOD', trl_type, 'TRTP', '') AS trl_type,
               trl_part,
               trl_price,
               CASE
                 WHEN trl_qty = 0 THEN trl_origqty
                 ELSE trl_qty
               END                                                 AS trl_qty,
               tra_auth,
               trl_event,
               trl_act,
               CASE tra_torentity
                 WHEN 'STOR' THEN tra_tocode
                 ELSE
                   CASE tra_fromrentity
                     WHEN 'STOR' THEN tra_fromcode
                   END
               END                                                 AS trl_store,
               trl_bin,
               trl_lot,
               DECODE(trl_io, 0, '+',
                              '-')                                 AS trl_io,
               trl_interface,
               trl_sourcecode,
               trl_acd,
               NULL                                                AS
               trl_udfchar01,
               NULL                                                AS
               trl_udfchar02,
               NULL                                                AS
               trl_udfchar03,
               NULL                                                AS
               trl_udfchar04,
               NULL                                                AS trl_desc,
               trl_udfnum04,
               trl_udfnum05,
               trl_date                                            AS
               trl_entered,
               tra_advice
        FROM   R5TRANSLINES,
               R5TRANSACTIONS
        WHERE  trl_trans = tra_code
               AND NVL(tra_routeparent, ' ') = ' '
               AND tra_status = 'A'
               AND tra_order IS NOT NULL
               AND trl_order IS NOT NULL
        UNION
        SELECT orl_order_org AS trl_order_org,
               orl_order     AS trl_order,
               orl_ordline   AS trl_ordline,
               boo_code      AS trl_trans,
               1             AS trl_line,
               boo_date      AS trl_date,
               CASE
                 WHEN NVL(boo_orighours, boo_hours) < 0 THEN 'Service returned'
                 ELSE 'Service received'
               END           AS trl_type,
               orl_udfchar27 AS trl_part,
               CASE
                 WHEN orl_type = 'SF' THEN NVL(boo_orighours, boo_cost)
                 ELSE orl_price
               END           AS trl_price,
               CASE
                 WHEN orl_type = 'SF' THEN 1
                 ELSE NVL(boo_orighours, boo_hours)
               END           AS trl_qty,
               boo_udfchar30 AS tra_auth,
               boo_event     AS trl_event,
               boo_act       AS trl_act,
               NULL          AS trl_store,
               NULL          AS trl_bin,
               NULL          AS trl_lot,
               '+'           AS trl_io,
               NULL          AS trl_interface,
               NULL          AS trl_sourcecode,
               boo_acd       AS trl_acd,
               boo_udfchar01 AS trl_udfchar01,
               boo_udfchar02 AS trl_udfchar02,
               boo_udfchar03 AS trl_udfchar03,
               boo_udfchar04 AS trl_udfchar04,
               boo_desc      AS trl_desc,
               boo_udfnum04,
               boo_udfnum05,
               boo_entered,
               boo_udfchar27
        FROM   R5BOOKEDHOURS,
               R5ACTIVITIES,
               R5ORDERLINES
        WHERE  boo_event = act_event
               AND boo_act = act_act
               AND ( ( orl_order = act_order
                       AND orl_ordline = act_ordline
                       AND act_ordered = '+' )
                      OR ( boo_order = orl_order
                           AND boo_ordline = orl_ordline
                           AND boo_order_org = orl_order_org ) )
               AND NVL(boo_routeparent, ' ') = ' '
               AND NVL(boo_person, ' ') = ' '
               AND NVL(orl_udfchar27, ' ') <> ' ') atl
WHERE  ord_code = orl_order
       AND ord_org = orl_order_org
       AND orl_req = rql_req
       AND orl_reqline = rql_reqline
       AND orl_order = trl_order
       AND orl_ordline = trl_ordline
       AND EXISTS (SELECT 1
                   FROM   R5USERORGANIZATION
                   WHERE  uog_org = orl_order_org
                          AND uog_user = :MP5USER) 
