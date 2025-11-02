-- 以下单时间
WITH monthly_gmv as (
SELECT
  DATE_FORMAT(order_purchase_timestamp,"%Y-%m") 月份,
  count(distinct order_id) 订单数,
  round(sum(gmv_value),2) 月GMV
FROM
  order_item_wide_gmv_cleaned
  GROUP BY 月份
  ORDER BY 月份
 )
 SELECT
    月份,
    订单数,
    月GMV / 订单数 as 客单价,
    月GMV,
    round((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) -1) *100,2) 环比百分比
 FROM monthly_gmv
 
-- 以送达时间
WITH monthly_gmv as (
SELECT
  DATE_FORMAT(order_delivered_customer_date,"%Y-%m") 月份,
  count(distinct order_id) 订单数,
  round(sum(gmv_value),2) 月GMV
FROM
  order_item_wide_gmv_cleaned
  GROUP BY 月份
  ORDER BY 月份
 )
 SELECT
    月份,
    订单数,
    月GMV / 订单数 as 客单价,
    月GMV,
    round((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) -1) *100,2) 环比百分比
 FROM monthly_gmv