# 📈 GMV 计算口径说明（SQL 分析）

> 清洗完数据后，我们基于两种不同的时间口径计算月度 GMV，  
> 以验证是否存在“时间错位假象”现象。

---

## 🕐 一、按下单时间（purchase_timestamp）

此口径反映用户下单时的业务表现，用于衡量**当期销售活跃度**。

```sql
-- 以下单时间为口径
WITH monthly_gmv AS (
  SELECT
    DATE_FORMAT(order_purchase_timestamp, "%Y-%m") AS 月份,
    COUNT(DISTINCT order_id) AS 订单数,
    ROUND(SUM(gmv_value), 2) AS 月GMV
  FROM order_item_wide_gmv_cleaned
  GROUP BY 月份
  ORDER BY 月份
)
SELECT
  月份,
  订单数,
  月GMV / 订单数 AS 客单价,
  月GMV,
  ROUND((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) - 1) * 100, 2) AS 环比百分比
FROM monthly_gmv;
````

💡 **说明：**

* `gmv_value = price + freight_value`
* 聚合维度为 **月份（purchase_timestamp）**
* `环比百分比` 用于观察月度 GMV 变化趋势
* 适合分析：销售动能、促销活动、下单行为等

---

## 🚚 二、按送达时间（delivered_customer_date）

此口径反映商家**履约节奏与平台成交兑现情况**，
更接近财务或运营视角的“实际成交”节奏。

```sql
-- 以送达时间为口径
WITH monthly_gmv AS (
  SELECT
    DATE_FORMAT(order_delivered_customer_date, "%Y-%m") AS 月份,
    COUNT(DISTINCT order_id) AS 订单数,
    ROUND(SUM(gmv_value), 2) AS 月GMV
  FROM order_item_wide_gmv_cleaned
  GROUP BY 月份
  ORDER BY 月份
)
SELECT
  月份,
  订单数,
  月GMV / 订单数 AS 客单价,
  月GMV,
  ROUND((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) - 1) * 100, 2) AS 环比百分比
FROM monthly_gmv;
```

💡 **说明：**

* 使用 `order_delivered_customer_date` 字段计算月度 GMV
* 可观察发货与签收时间滞后的影响
* 适合分析：物流延迟、履约节奏、确认收货周期

---

## 🧭 三、结果对比与分析思路

| 维度     | 含义          | 适用分析场景      |
| ------ | ----------- | ----------- |
| 下单时间口径 | 用户下单当月的销售表现 | 市场营销、促销活动效果 |
| 送达时间口径 | 实际履约完成的 GMV | 供应链、履约节奏分析  |

✨ 当发现两者在同一时间段存在显著差异（如：11 月 GMV 下降但 12 月上升），
说明可能存在 **“时间错位假象”**——
即订单在 11 月下单但在 12 月送达，从而造成 GMV 口径差异。📦📉📈

---


## 下单时间口径GMV计算结果
<img width="1172" height="1072" alt="image" src="https://github.com/user-attachments/assets/2a39e273-9142-4f32-a530-0cd90682794c" />

## 送达时间口径GMV计算结果
注:将月份为NUll及2018.09 2018.10月份的数据过滤
<img width="1104" height="1050" alt="image" src="https://github.com/user-attachments/assets/9cd28752-b2fc-456e-8d17-4461fa9e8ea3" />



