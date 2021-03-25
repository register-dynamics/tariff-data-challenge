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
)
SELECT
  gn.goods_nomenclature_sid AS sid,
  gn.goods_nomenclature_item_id AS code,
  gn.producline_suffix AS suffix,
  d.description AS description,
  gn.validity_start_date :: date AS validity_start_date,
  gn.validity_end_date :: date AS validity_end_date
FROM
  goods_nomenclatures gn
  LEFT OUTER JOIN all_descs d ON gn.goods_nomenclature_sid = d.area_sid
  AND d.validity_start_date <= '2021-01-01' :: date
  AND (
    d.validity_end_date >= '2021-01-01' :: date
    or d.validity_end_date IS NULL
  )
WHERE
  gn.goods_nomenclature_item_id LIKE '01%'
ORDER BY
  goods_nomenclature_item_id,
  producline_suffix