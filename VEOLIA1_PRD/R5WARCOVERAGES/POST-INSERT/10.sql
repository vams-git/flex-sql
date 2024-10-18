DECLARE
    wcv     r5warcoverages % ROWTYPE;
    cnt     NUMBER;
    ierrmsg VARCHAR2(255);
    err_chk EXCEPTION;
    CURSOR cur_wcvrank(
      vobject    VARCHAR2,
      vobjectorg VARCHAR2,
      vwarranty  VARCHAR2 ) IS
      SELECT wcv_seqno,
             wcv_active,
             Rank()
               over (
                 PARTITION BY wcv_object, wcv_object_org, wcv_warranty
                 ORDER BY wcv_expirationdate DESC, wcv_expiration DESC ) AS
             wcv_rank
      FROM   r5warcoverages
      WHERE  wcv_object = vobject
             AND wcv_object_org = vobjectorg
             AND wcv_warranty = vwarranty;
BEGIN
    SELECT *
    INTO   wcv
    FROM   r5warcoverages
    WHERE  ROWID = :rowid;

    IF Nvl(wcv.wcv_active, '-') = '+'
       AND NOT ( wcv.wcv_nearthreshold IS NOT NULL
                 AND ( wcv.wcv_startdate IS NOT NULL
                        OR wcv.wcv_startusage IS NOT NULL ) ) THEN
      ierrmsg := 'Input Treshold and Start to Activate';

      RAISE err_chk;
    END IF;

    --count total warranty for asset
    SELECT Count(1)
    INTO   cnt
    FROM   r5warcoverages
    WHERE  wcv_object = wcv.wcv_object
           AND wcv_object_org = wcv.wcv_object_org
           AND wcv_warranty = wcv.wcv_warranty;

    IF cnt = 0
       AND Nvl(wcv.wcv_active, '-') = '-' THEN
      UPDATE r5warcoverages
      SET    wcv_active = '+'
      WHERE  wcv_seqno = wcv.wcv_seqno;
    END IF;

    IF cnt > 0 THEN
      FOR rec_w IN cur_wcvrank( wcv.wcv_object, wcv.wcv_object_org,
      wcv.wcv_warranty
      ) LOOP
          IF rec_w.wcv_rank = 1
             AND Nvl(rec_w.wcv_active, '-') = '-' THEN
            UPDATE r5warcoverages
            SET    wcv_active = '+'
            WHERE  wcv_seqno = rec_w.wcv_seqno;
          END IF;

          IF rec_w.wcv_rank > 1
             AND Nvl(rec_w.wcv_active, '-') = '+' THEN
            UPDATE r5warcoverages
            SET    wcv_active = '-'
            WHERE  wcv_seqno = rec_w.wcv_seqno;
          END IF;
      END LOOP;
    END IF;
EXCEPTION
    WHEN err_chk THEN
      Raise_application_error (-20003, ierrmsg);
    WHEN OTHERS THEN
      ierrmsg := 'Error in FlexSql on r5warcoverages-Validate Active Warranty';

      Raise_application_error (-20003, ierrmsg);
END; 