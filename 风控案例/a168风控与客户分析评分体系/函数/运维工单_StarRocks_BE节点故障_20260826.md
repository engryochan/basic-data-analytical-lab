# StarRocks BE 节点故障报修单

**报修人**：Ryo Eng（数据分析 · Superset SQL Lab 只读账号）
**发生日期**：2026-08-26
**受影响节点**：`BE:10265 (172.31.94.175)`、`BE:10266 (172.31.89.70)`
**另有一节点撞过内存但未被拉黑**：`BE:10267 (172.31.80.38)`

---

## 一、我请求的是什么

**不是请求解除黑名单。** 黑名单是结果，不是原因。
在根因未处理前解除，节点会立刻被再次拉黑。

**我请求的是：**

1. 确认两个 BE 当前的**进程状态**与**磁盘余量**
2. 若 `/opt/starrocks/be/spill/` 被残留文件占满，请清理
3. 根因处理完毕后，再由贵方判断是否需要移出黑名单
4. 告知我一个**安全的资源上限**（见第五节），我据此调整查询

---

## 二、事发经过（按时间顺序，全部为实际报错原文）

### 阶段一 · 内存超限

```
Memory of process exceed limit. Backend: 172.31.94.175
Used: 85,199,919,067   Limit: 107,092,346,019    BE:10265

Memory of process exceed limit. Backend: 172.31.80.38
Used: 106,274,909,618  Limit: 107,092,346,019    BE:10267

Memory of process exceed limit. Backend: 172.31.89.70
Used: 107,095,273,592  Limit: 107,092,346,019    BE:10266
```

### 阶段二 · 我调整了会话参数（这一步是我的操作，需说明）

为规避内存超限，我在**会话级**设置了：

```sql
SET enable_spill = true;
SET spill_mode = 'force';     -- ★ 这一项是本次事故的关键
SET spill_operator_min_bytes = 10485760;
```

`spill_mode = 'force'` 会让**所有相关算子强制落盘**，而非仅在内存吃紧时落盘。
**我当时没有先确认 spill 目录的可用容量。**

### 阶段三 · 磁盘写满

```
/opt/starrocks/be/spill/01a03e9c-.../...-local-sort-spill-5-15
    : No space left on device   BE:10265

/opt/starrocks/be/spill/01a03e9d-.../...-local-sort-spill-151-16
    : No space left on device   BE:10265

/opt/starrocks/be/spill/01a03e9d-.../...-hash-join-probe-13-56
    : No space left on device   BE:10266
```

### 阶段四 · 节点被拉黑

```
Backend node not found. backend: [172.31.94.175  alive: false  inBlacklist: false]
Backend node not found. backend: [172.31.94.175  alive: false  inBlacklist: true ]   （出现 3 次）
Backend node not found. backend: [172.31.89.70   alive: false  inBlacklist: true ]
```

### 阶段五 · `BE:10266` 疑似自行恢复，但内存仍紧张

```
Backend node not found. backend: [172.31.89.70   alive: TRUE   inBlacklist: true ]

Memory of process exceed limit. Backend: 172.31.89.70
Used:  66,602,417,232   BE:10266
Used:  99,833,804,489   BE:10266
Used: 107,106,609,313   BE:10266
```

`alive: true` 且随后能报出内存使用量，说明该 BE 进程当时是活着的，
但仍留在黑名单内。**`BE:10265` 未观察到类似的 `alive: true`。**

---

## 三、请贵方协助确认的四项

| # | 检查 | 目的 |
|---|---|---|
| 1 | `SHOW BACKENDS;` → 两节点的 `Alive` / `LastHeartbeat` / `AvailCapacity` / `MaxDiskUsedPct` / `ErrMsg` | 分辨是「进程已停」还是「进程在但磁盘满」 |
| 2 | `SHOW BACKEND BLACKLIST;` → 看 `AddBlackListType` 是 `AUTO` 还是 `MANUAL` | `AUTO` 可能自动恢复；`MANUAL` 必须人工删除 |
| 3 | 两节点 `/opt/starrocks/be/spill/` 的实际占用与残留文件 | 确认是否为本次 spill 撑满 |
| 4 | 该目录与数据盘是否同一块物理盘 | 官方建议 spill 与数据存储分盘 |

**若第 1 项显示进程已停，请重启 BE。** StarRocks 在 BE 重启时会清理崩溃前遗留的 spill 数据。

---

## 四、我这边已经做的整改

| 项 | 改动 |
|---|---|
| `spill_mode` | `force` → **`auto`**（仅内存吃紧时才落盘） |
| `spill_operator_min_bytes` | 10 MB → **1 GB**（小算子不再落盘，避免碎片文件） |
| `pipeline_dop` | `0`（自动全核）→ **`4`**（降低并行度与瞬时内存） |
| 查询本身 | 已把一处 `SELECT b.*` 改为显式 26 列，减少约 57% 的中间物化量 |
| 执行方式 | 停止多标签并行，改为**串行**执行 |
| 最重的一件查询 | 暂缓，先跑其余较轻的作业 |

---

## 五、想请教贵方的三个问题

1. **spill 目录的可用容量约有多少？** 我据此判断哪些查询能开 spill。
2. **单条查询的内存上限，建议控制在什么量级？**
   现行 BE 进程上限约 107 GB，但那是全节点共享；我需要知道单查询的合理配额。
3. **是否有推荐的资源组（resource group）** 可供分析类只读查询使用，
   以避免影响线上业务？

---

## 六、我的作业性质说明

- 只读查询，**未做任何写入、建表、删除**
- 主表 `ods_mariadb_2b.ods_a168_bet02`，分析窗口 139 天，约 1.26 亿行
- 最重的一件需要：全表去重（窗口函数）＋ 分组聚合＋分位数＋全局排序
- 该件已改为分批取数，但**每一批都会重算全表**，是本次压力的主要来源

**若贵方认为此类查询不宜在生产集群执行，请告知，我会调整作业方式或另寻资源。**

---

## 七、责任说明

`spill_mode = 'force'` 是我在未确认磁盘容量的情况下设置的，
是本次磁盘写满的直接诱因。该参数已撤除，不会再作为常设配置使用。

给贵方添麻烦，抱歉。
