# 🧹 数据预处理说明文档（Data Cleaning & Preparation）

> 本文档记录了对 Olist 巴西电商数据集的预处理流程与逻辑说明。  
> 数据来源：`olist_orders_dataset.csv`、`olist_order_items_dataset.csv`  
> 主要目的是生成一份干净、可用于 GMV 分析的订单明细表。

---

## 📦 一、数据读取与基础信息

```python
import pandas as pd

orders_table = pd.read_csv("../data/olist_orders_dataset.csv")
order_item_table = pd.read_csv("../data/olist_order_items_dataset.csv")
````

---

## 🧽 二、异常时间段清理

在 `orders_table` 中，通过分析发现部分月份的订单占比极低，样本稀疏、业务无参考价值，因此直接删除这些时间段的数据：

| 时间段（purchase_timestamp 口径） | 订单占比   | 处理方式 |
| -------------------------- | ------ | ---- |
| 2016年9月、10月、12月            | < 0.3% | 删除   |
| 2018年9月、10月                | < 0.1% | 删除   |

```python
periods_to_remove = [
    (2016, 9), (2016, 10), (2016, 12),
    (2018, 9), (2018, 10)
]
```

---

## 💰 三、金额字段异常与极值处理

### 3.1 检查异常金额（负数）

对 `order_item_table` 的 `price` 与 `freight_value` 进行异常检查：

```python
anomalies = order_item_table[(order_item_table['price'] <= 0) | (order_item_table['freight_value'] < 0)]
```

结果：**异常记录数为 0**，无需处理。

---

### 3.2 去除极端尾值（99 分位截断）

为防止极端高价订单对 GMV 拉动失真，截断 99% 分位后的异常值：

| 字段            | 99% 分位值 | 最大值    | 处理方式            |
| ------------- | ------- | ------ | --------------- |
| price         | 890     | 6735   | 超出部分重置为 99% 分位值 |
| freight_value | 84.52   | 409.68 | 超出部分重置为 99% 分位值 |

```python
p99_price = order_item_table['price'].quantile(0.99)
p99_freight_value = order_item_table['freight_value'].quantile(0.99)
```

---

## 🔗 四、订单与明细关联完整性检查

1. **items 无对应订单**

   * 数量：371 条
   * 原因：多数为 2016 年及 2018-09~10 的无效订单
   * 处理：从 item 表中剔除

2. **orders 无对应明细**

   * 数量：739 条
   * 原因：状态异常（如未付款、取消订单等）
   * 处理：从 orders 表中剔除

```python
order_item_table = order_item_table[order_item_table['order_id'].isin(orders_table['order_id'])]
orders_table = orders_table[orders_table['order_id'].isin(order_item_table['order_id'])]
```

---

## 📊 五、订单状态过滤

订单状态分布如下：

| 状态                              | 数量    | 占比     |
| ------------------------------- | ----- | ------ |
| delivered                       | 96211 | 97.82% |
| 其他状态（canceled / shipped / etc.） | 2.18% | 已剔除    |

🔹 **分析口径：仅保留 `delivered` 状态订单。**

```python
orders_table = orders_table[orders_table['order_status'] == 'delivered']
```

---

## 💡 六、构建 GMV 字段

GMV 定义为：

> `gmv_value = price + freight_value`

```python
order_item_table['gmv_value'] = order_item_table['price'] + order_item_table['freight_value']
```

---

## 🧮 七、生成清洗后明细表

对订单与明细表进行 **内连接（inner join）**：

> 仅保留两表中均存在的有效订单记录。

```python
order_item_wide = orders_table.merge(order_item_table[['order_id', 'gmv_value']], on='order_id', how='inner')
order_item_wide.to_csv("../processed/order_item_wide_gmv_cleaned.csv", index=False)
```

输出文件路径：

```
../processed/order_item_wide_gmv_cleaned.csv
```

---

## ✅ 八、清洗结果概要

| 步骤   | 操作说明             | 结果                   |
| ---- | ---------------- | -------------------- |
| 时间过滤 | 删除异常时间段          | 保留 2017.01 ~ 2018.08 |
| 金额清洗 | 去除负值与极端尾值        | 保留 99% 合理区间          |
| 数据对齐 | 删除无关联订单与明细       | 订单明细一一对应             |
| 状态筛选 | 仅保留 delivered 订单 | GMV 口径统一             |
| 字段构建 | 新增 gmv_value 字段  | 可用于后续聚合分析            |

---
