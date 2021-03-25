SELECT
  goods_nomenclature_sid AS sid,
  number_indents AS indent,
  validity_start_date::date AS validity_start_date
FROM
  goods_nomenclature_indents
WHERE
  goods_nomenclature_item_id LIKE '01%'
ORDER BY goods_nomenclature_sid