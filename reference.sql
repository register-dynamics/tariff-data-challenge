START TRANSACTION;

-- We create a mapping of CCs to the next CC with the same indent
-- that we will use later to inherit down down to CCs that don't
-- have their own measures. We do this using a window function by
-- ordering by CC and then selecting the next row with the same indent.
-- We do this as a temporary table rather than a CTE so that we can
-- put some indexes on it.
CREATE TEMPORARY TABLE ccs (
  cc char(10),
  sid int4,
  indent integer,
  next char(10),
  next_suffix char(2),
  next_sid int4,
  producline_suffix char(2)
) ON COMMIT DROP;

CREATE INDEX ON ccs (producline_suffix, cc);

CREATE INDEX ON ccs (cc);

CREATE INDEX ON ccs (next);

CREATE INDEX ON ccs (sid);

CREATE INDEX ON ccs (next_sid);

WITH live_codes AS (
  SELECT
    *
  FROM
    goods_nomenclatures
  WHERE
    goods_nomenclatures.goods_nomenclature_item_id LIKE '01%'
    AND (
      goods_nomenclatures.validity_end_date IS NULL
      OR goods_nomenclatures.validity_end_date > '2021-01-01' :: date
    )
),
basic_indents AS (
  SELECT
    gni.goods_nomenclature_indent_sid,
    gni.goods_nomenclature_sid,
    gni.validity_start_date,
    MAX(gni.validity_start_date) OVER (
      PARTITION BY gni.goods_nomenclature_sid
      ORDER BY
        gni.validity_start_date ASC ROWS BETWEEN CURRENT ROW
        AND 1 FOLLOWING
    ) AS validity_end_date,
    (
      CASE
        WHEN gn.goods_nomenclature_item_id LIKE '%00000000' THEN -1
        ELSE gni.number_indents
      END
    ) AS number_indents,
    gn.goods_nomenclature_item_id,
    gn.producline_suffix,
    gn.validity_start_date AS gn_start,
    gn.validity_end_date AS gn_end
  FROM
    goods_nomenclature_indents AS gni
    LEFT OUTER JOIN goods_nomenclatures gn ON gni.goods_nomenclature_sid = gn.goods_nomenclature_sid
),
goods_indents AS (
  SELECT
    goods_nomenclature_indent_sid,
    goods_nomenclature_sid,
    validity_start_date :: date,
    (
      CASE
        WHEN basic_indents.validity_end_date = basic_indents.validity_start_date THEN NULL
        ELSE basic_indents.validity_end_date
      END
    ) :: date AS validity_end_date,
    number_indents,
    goods_nomenclature_item_id,
    producline_suffix,
    gn_start,
    gn_end
  FROM
    basic_indents
),
parents AS (
  SELECT
    parents.*,
    (
      CASE
        WHEN parents.goods_nomenclature_item_id LIKE '%00000000' THEN -1
        ELSE parent_indents.number_indents
      END
    ) AS number_indents
  FROM
    live_codes AS parents
    LEFT OUTER JOIN goods_indents AS parent_indents ON parents.goods_nomenclature_sid = parent_indents.goods_nomenclature_sid
  WHERE
    parent_indents.validity_start_date <= '2021-01-01' :: date
    AND (
      parent_indents.validity_end_date >= '2021-01-01' :: date
      OR parent_indents.validity_end_date IS NULL
    )
)
INSERT INTO
  ccs
SELECT
  parents.goods_nomenclature_item_id as cc,
  parents.goods_nomenclature_sid AS sid,
  parents.number_indents as indent,
  LEAD(parents.goods_nomenclature_item_id) OVER (
    PARTITION BY parents.number_indents
    ORDER BY
      parents.goods_nomenclature_item_id,
      parents.producline_suffix
  ) AS next,
  LEAD(parents.producline_suffix) OVER (
    PARTITION BY parents.number_indents
    ORDER BY
      parents.goods_nomenclature_item_id,
      parents.producline_suffix
  ) AS next_suffix,
  LEAD(parents.goods_nomenclature_sid) OVER (
    PARTITION BY parents.number_indents
    ORDER BY
      parents.goods_nomenclature_item_id
  ) AS next_sid,
  parents.producline_suffix AS producline_suffix
FROM
  parents;

-- Now we create the mapping of CCs to all descendent CCs.
-- We do this using the table above, selecting all of the CCs
-- that exist between the two limits and at a greater indent.
-- Again we do this as a temporary table so we can take advantage
-- of indexes.
CREATE TEMPORARY TABLE cc_children (
  parent_sid int4,
  parent_cc char(10),
  parent_suffix char(2),
  parent_indent integer,
  child_sid int4,
  child_cc char(10),
  child_suffix char(2),
  child_indent integer
) ON COMMIT DROP;

CREATE INDEX ON cc_children (parent_sid);

CREATE INDEX ON cc_children (child_sid);

INSERT INTO
  cc_children
SELECT
  cc1.sid as parent_sid,
  cc1.cc as parent_cc,
  cc1.producline_suffix as parent_suffix,
  cc1.indent as parent_indent,
  cc2.sid as child_sid,
  cc2.cc as child_cc,
  cc2.producline_suffix as child_suffix,
  cc2.indent as child_indent
FROM
  ccs as cc1,
  ccs as cc2
WHERE
  cc2.cc >= cc1.cc
  AND (
    cc2.cc < cc1.next
    OR cc1.next IS NULL
  )
  AND cc2.indent = cc1.indent + 1;

-- Finally we use the mapping. We must also select the correct description
-- because in the full data model descriptions are dated too – in the challenge
-- data model they are not.
WITH all_rows AS (
  SELECT
    gadp.goods_nomenclature_description_period_sid AS sid,
    gadp.goods_nomenclature_sid AS area,
    gad.description,
    gadp.validity_start_date,
    MAX(gadp.validity_start_date) OVER (
      PARTITION BY gadp.goods_nomenclature_sid
      ORDER BY
        gadp.validity_start_date ASC ROWS BETWEEN CURRENT ROW
        AND 1 FOLLOWING
    ) AS validity_end_date
  FROM
    goods_nomenclature_description_periods gadp
    LEFT OUTER JOIN goods_nomenclature_descriptions gad ON gad.goods_nomenclature_description_period_sid = gadp.goods_nomenclature_description_period_sid
),
all_descs AS (
  SELECT
    all_rows.sid AS period_sid,
    all_rows.area AS area_sid,
    COALESCE(all_rows.description, '') :: text AS description,
    all_rows.validity_start_date :: date,
    (
      CASE
        WHEN all_rows.validity_end_date = all_rows.validity_start_date THEN NULL
        ELSE all_rows.validity_end_date - INTERVAL '1 DAY'
      END
    ) :: date AS validity_end_date
  FROM
    all_rows
  ORDER BY
    area_sid ASC
),
all_codes AS (
  SELECT
    child_sid AS sid,
    parent_sid AS parent
  FROM
    cc_children
  UNION
  SELECT
    sid,
    NULL AS parent
  FROM
    ccs
  WHERE
    indent = -1
)
SELECT
  all_codes.sid,
  children.goods_nomenclature_item_id AS commodity_code,
  children.producline_suffix AS suffix,
  all_descs.description,
  children.validity_start_date::date,
  children.validity_end_date::date,
  all_codes.parent AS parent_sid,
  parents.goods_nomenclature_item_id AS parent_code
FROM
  all_codes
  LEFT OUTER JOIN goods_nomenclatures children ON all_codes.sid = children.goods_nomenclature_sid
  LEFT OUTER JOIN goods_nomenclatures parents ON all_codes.parent = parents.goods_nomenclature_sid
  LEFT OUTER JOIN all_descs ON all_codes.sid = all_descs.area_sid
    AND all_descs.validity_start_date <= '2021-01-01'
    AND (
      all_descs.validity_end_date >= '2021-01-01'
      OR all_descs.validity_end_date IS NULL
    )
ORDER BY
  children.goods_nomenclature_item_id,
  children.producline_suffix;

COMMIT;