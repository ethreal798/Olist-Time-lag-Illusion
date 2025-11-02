# 🧩 Olist 电商数据分析：GMV 异动与时间错位验证

## 一、数据预处理

数据来自巴西电商平台 **Olist**，主要使用以下表：

* `orders_table`：订单主表
* `order_item_table`：订单明细表

数据预处理主要步骤如下：

1. **去除异常时间段订单**

   * 发现 `(2016年9月、10月、12月)` 与 `(2018年9月、10月)` 的订单占比极低，数据不具参考价值；
   * 这些时间段可能是数据收集不完整或平台初期测试阶段，因此直接剔除。

2. **金额异常检查**

   * 检查 `price`、`freight_value` 是否存在负值；
   * 无负值记录，保留全部。

3. **极端值处理**

   * `price` 的 99% 分位数为 `890`，最大值高达 `6735`；
   * `freight_value` 的 99% 分位数为 `84.52`，最大值 `409.68`；
   * 将超过 99% 分位的值截断，以避免极端尾值拉高整体 GMV。

4. **关联完整性检查**

   * `order_item_table` 中有部分订单在 `orders_table` 中不存在（约 371 条），经查主要为已删除时间段；
   * 同时，`orders_table` 中存在 739 条无明细订单，疑为异常状态订单；
   * 均予以剔除。

5. **状态筛选**

   * `delivered` 状态订单占比达 **97.8%**；
   * 为保证 GMV 口径一致，仅保留 **已送达订单**。

6. **构建 GMV 字段**

   ```python
   order_item_table['gmv_value'] = order_item_table['price'] + order_item_table['freight_value']
   ```

   合并订单主表与明细表，输出清洗结果：

   ```
   ../processed/order_item_wide_gmv_cleaned.csv
   ```

---

## 二、SQL 分析逻辑

为了验证 GMV 异动是否存在“时间错位”问题，我们分别以 **下单时间** 与 **送达时间** 为口径计算月度 GMV。

### 💡 计算逻辑

#### 1️⃣ 以「下单时间」为准

```sql
WITH monthly_gmv AS (
  SELECT
    DATE_FORMAT(order_purchase_timestamp, "%Y-%m") AS 月份,
    COUNT(DISTINCT order_id) AS 订单数,
    ROUND(SUM(gmv_value), 2) AS 月GMV
  FROM order_item_wide_gmv_cleaned
  GROUP BY 月份
)
SELECT
  月份,
  订单数,
  月GMV / 订单数 AS 客单价,
  月GMV,
  ROUND((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) - 1) * 100, 2) AS 环比百分比
FROM monthly_gmv;
```

#### 2️⃣ 以「送达时间」为准

```sql
WITH monthly_gmv AS (
  SELECT
    DATE_FORMAT(order_delivered_customer_date, "%Y-%m") AS 月份,
    COUNT(DISTINCT order_id) AS 订单数,
    ROUND(SUM(gmv_value), 2) AS 月GMV
  FROM order_item_wide_gmv_cleaned
  GROUP BY 月份
)
SELECT
  月份,
  订单数,
  月GMV / 订单数 AS 客单价,
  月GMV,
  ROUND((月GMV / NULLIF(LAG(月GMV, 1) OVER (ORDER BY 月份), 0) - 1) * 100, 2) AS 环比百分比
FROM monthly_gmv;
```

---

## 三、发现 GMV 异动

将两种口径结果导出至 Excel 后绘制月度 GMV 趋势图，发现：

| 时间          | purchase口径GMV | delivered口径GMV | 差异       | 说明   |
| ----------- | ------------- | -------------- | -------- | ---- |
| 2017-10     | 717,656       | 724,953        | -1%      | 正常   |
| **2017-11** | **1,115,402** | **727,643**    | **+53%** | 异常上升 |
| **2017-12** | **818,080**   | **1,069,155**  | **-23%** | 异常下滑 |

📈 如图所示，11 月 GMV 在「下单时间口径」出现大幅增长，而「送达时间口径」并未同步上升；
12 月则出现反向补偿现象 —— delivered GMV 高于 purchase GMV。

---

## 四、时间错位验证结论

* 🕐 **现象**：
  GMV 在 2017 年 11 月出现显著异动，下单口径上升 53%，送达口径滞后反应至 12 月。

* 🧭 **推论**：
  存在明显的 **“时间错位效应”** —— 大量 11 月下单的订单在 12 月才送达并记入 GMV。

* 🧩 **解释**：

  * 并非真实销量异常；
  * 而是由订单履约周期差异（如发货延迟、物流周期）导致；
  * 电商旺季（如黑五促销）期间订单集中下单但分月送达。

---

## 五、结论与启示

| 关键点              | 启示               |
| ---------------- | ---------------- |
| GMV 异动不一定代表业务波动  | 分析需区分下单与送达口径     |
| 履约周期可能引入统计偏差     | 建议在报表系统中同步展示两种口径 |
| 数据驱动决策的前提是理解业务节奏 | 光看数字很容易“被假象骗了”   |

---

