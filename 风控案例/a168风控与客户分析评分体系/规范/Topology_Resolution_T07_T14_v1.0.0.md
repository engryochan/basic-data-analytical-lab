# `Topology Resolution` · T-07 ／ T-14 · v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**ARTIFACT CLASS**：`A3 SPEC`　**canonical**：`false`
**承**：`Metric_Contract_Phase0.5_v1.0.0.md`
**范围**：二项 **Topology-resolvable** 之拓扑修订（**非「自解」**）

---

## 〇、正名 · `Topology-resolvable` ≠ 自解（我方自纠）

我上册书此二项为「**自解**」。**该词误导**——它暗示改完 grain 即成。

**实况**：

$$\text{Topology-resolvable} = \text{不需外部数据} \;\wedge\; \textbf{仍须重定义并验证 contract}$$

**二者不可混用。** 「不必等数据方」与「已经解决」隔着整个验证层。

```
T-07  STRUCTURALLY_FORBIDDEN
        ↓ topology revision
      qualified_win_rate
        ↓ validation
      PENDING_VALIDATION        ← 终点在此，非 DECISION

T-14  ROI at treatment-event grain
        ↓ topology revision
      member × treatment × window
        ↓ exposure validation
      PENDING_VALIDATION        ← 同上
```

---

## 一、★ 血统锁（本册最要紧之一条）

**锁三十八 · 改 grain 后所生之新 metric，不得继承旧 metric 之任何属性。**

**不得继承者四**：`evidence_tier` ／ `threshold` ／ `direction` ／ `admission`

$$\texttt{win\_rate\_all} \;\ne\; \texttt{qualified\_win\_rate}$$
$$\texttt{T-14 event-level ROI} \;\ne\; \texttt{T-14 member-window }\Delta\text{ROI}$$

**纵然数学上同名为 ROI，亦须视为新 metric lineage。**

> **拓扑变了、指标名没变，于是旧判据被错误继承——此害甚于单纯阈值错误。**
> 阈值错尚可自数据看出；**血统错则一路正确地算出错误的东西。**

**落地要求**：新 metric 须另立 `metric_id`，其 `evidence_tier` 自 `UNKNOWN` 起算，**禁自旧条目复制任何一栏**。

---

## 二、T-07 · 拓扑修订

### 现况（保持不动）

```
T-07   grain  = 混合全部注单
       metric = win_rate_all
       status = STRUCTURALLY_FORBIDDEN
       reason = mixture confounding
```

**实测之据**（`§M0-5b`）：

| 注型 | `n` | 命中率 |
|:--|--:|--:|
| Banker | 46,822,113 | **55.35%** |
| Tie | 9,642,347 | **9.47%**（赔 8:1） |

$$\text{胜率随玩法配比而变} \;\Longrightarrow\; \text{「技术能力」与「玩法结构」不可分离}$$

### 新 contract candidate

```
grain = member × game × bet_type × time_window
```

**须拆开者**：`Banker` ／ `Player` ／ `Tie` ／ 边注族 ／ 其余 `bet_type`
（`bet09` 实测 23 种玩法，`§M0-1` 已出 32 组可登记）

### ★★ 真正的难处不在拆分，在 `qualifying`

**禁**：

```sql
SUM(win_flag) / COUNT(*)
```

**何以禁**：取消单、和局、未结算、无效单**会重新污染分母**——拆了玩法，却让另一族杂质进来。

**故须先定义「何谓一笔合格结算注」：**

| 待定 | 现况 |
|:--|:--|
| 结算态之判别 | `category = '1'` 为一般注单，惟「已结算」之判据未单独定 |
| 和局之处置 | Tie 之退还注（push）算不算分母？ |
| 取消／无效单 | 判别字段未定 |
| 重对单 | `bet38 = 'N'` 已在基础闸，可复用 |
| 测试线 | 五级代理排除，已在基础闸 |

$$\texttt{win\_rate} = \frac{\text{winning \textbf{qualifying} bets}}{\text{\textbf{qualifying} settled bets}}$$

**分子分母之 `qualifying` 须同一集合**——此为本式之唯一要害。

### 裁定

```
old  win_rate_all        STRUCTURALLY_FORBIDDEN   （保持）
new  qualified_win_rate  PENDING_VALIDATION       （待 qualifying 定义）
     metric_role         PROFILE                  （★ 不批准升 DECISION）
     evidence_tier       UNKNOWN                  （★ 自零起算，禁继承）
```

---

## 三、T-14 · 拓扑修订（★ 须更谨慎）

### 现况（保持不动）

```
T-14   grain  = 处置事件
       metric = ROI
       status = STRUCTURALLY_FORBIDDEN
       reason = 事件粒度无投注收益分母
```

### 改 grain 只解决一件事

$$\text{改 grain} \;\Longrightarrow\; \text{ROI 不再属于处置事件本身}$$

**未自动解决者七**：

```
treatment window  ／  baseline window  ／  post window  ／  eligibility
exposure          ／  overlap          ／  censoring
```

**故不得宣布「已解」。**

### 新 contract candidate

```
T-14 treatment event
        ↓
member × treatment event
        ↓
pre-treatment window   →  ROI_pre
        ↓
post-treatment window  →  ROI_post
        ↓
economic outcome       →  ΔROI ／ NEV
```

### ★★ 零暴露之处置（承「零不与有值共用判词」）

**若某会员被限红后根本未下注：**

$$\text{ROI}_{post} = \frac{?}{0}$$

**禁写 `0%`。** 分母为零非「收益为零」，是**没有可算之基**。

**须判**：

```
NOT_APPLICABLE      或      NO_EXPOSURE
```

★ **此正是 `§VB-41b` 之「零对零 ≠ 有值相同」原则在经济层之复现**：

| 情形 | 判 |
|:--|:--|
| 处置后下注 100 万、净赢零 | `ROI_post = 0%` **有值** |
| 处置后完全未下注 | **`NO_EXPOSURE`** —— 无可算之基 |

**二者共用 `0%` 即掩盖了「处置令其停止下注」这一最重要的处置效果。**

**且这恰是商业上最要紧的信号**：限红后不再下注，可能是**处置奏效**，亦可能是**优质客户流失**——`0%` 会把两者一并抹平。

### 未定之七项 · 逐条

| 项 | 待定 |
|:--|:--|
| `treatment window` | 处置生效之时点（`limit_change_time` 现 `BLOCKED`） |
| `baseline window` | 前窗长度、是否等长 |
| `post window` | 后窗长度、右删失如何处置 |
| `eligibility` | 何种会员合格入组 |
| `exposure` | **零暴露之判词（见上）** |
| `overlap` | 同一会员多次处置之窗口重叠 |
| `censoring` | 窗末未满者 |

### 裁定

```
old  ROI @ treatment-event grain      STRUCTURALLY_FORBIDDEN   （保持）
new  ΔROI @ member × treatment × window
     status        PENDING_VALIDATION
     metric_role   PROFILE
     evidence_tier UNKNOWN            （★ 禁继承）
     ⚠ 前置：limit_change_time 现 BLOCKED(B-09)，PIT 未重建
```

★ **须记明**：T-14 之新拓扑虽属 topology-resolvable，**其 exposure validation 仍卡在 `effective_limit` 之 PIT 重建**（`NOT_AVAILABLE`）。**故新 contract 可立，实测不可行。**

---

## 四、T-15 · 保持 `NOT_IDENTIFIABLE`，不攻

```
T-15   status                NOT_IDENTIFIABLE
       candidate_resolution  PIT registration boundary
       verification_status   UNVERIFIED
```

**`member.dt = registration_date` 系线索，非证据。** 须先证：

```
registration_date  →  可作观察窗左边界
                   →  可区分 pre-window member 与 window-new member
                   →  silent_days 方可识别
```

**锁三十九**：**线索不是证据，候选解法不是已解 contract。**

---

## 五、★ `PENDING_INVERSE` 之正名（承裁示第七节）

**禁读作**：「只差一个阈值。」

**实为四层依赖：**

$$\text{Contract} \to \text{合法 denominator} \to \text{Distribution} \to \text{direction} \to \text{threshold}$$

**锁四十**：**`PENDING_INVERSE` 是结果状态，不是施工任务。**

**故 36 条 `PENDING_INVERSE` 不可直接排工**——须先看其上游四层各卡在何处。以现况计：

| 上游层 | 卡住之数 |
|:--|--:|
| denominator 未定 | 10 类 |
| `direction` 空白 | 23 条 |
| `evidence_tier = UNKNOWN` | 35 条 |

**三者交集处，方是真正可动之处。**

---

## 六、修订后之分母缺口

| 状态 | 修订前 | 修订后 |
|:--|--:|--:|
| 已定 | 5 | 5 |
| `PENDING_VALIDATION` | 6 | **8**（＋T-07／T-14 之新 contract） |
| `NOT_AVAILABLE` | 2 | 2 |
| `STRUCTURALLY_FORBIDDEN` | 2 | **2**（旧定义保持，未删） |
| `NOT_IDENTIFIABLE` | 1 | 1 |

★ **数目未减，性质已变**：

> 二项自「**当前 grain 下数学不成立**」转为「**新 grain 已立，待验证**」。
> **旧定义不删——它是血统之一部分，删则无从追溯何以改。**

---

## 七、口诀

> **结构能自解，先改拓扑；拓扑一改，血统重立；旧指标不继承新意义，旧阈值不继承新分母；先合法，再取数，最后才反解。**

**本册三锁**：

> **锁三十八**：改 grain 后之新 metric，不得继承旧 metric 之 `evidence_tier`／`threshold`／`direction`／`admission`。
> **锁三十九**：线索不是证据，候选解法不是已解 contract。
> **锁四十**：`PENDING_INVERSE` 是结果状态，不是施工任务。

---

```
Topology Resolution   T-07 ／ T-14 已出，皆落 PENDING_VALIDATION
Metric Contract       分子层 ← NEXT
v11.0.3               LOCKED ／ 03E774DE ／ 未触一字
v11.0.4               不启动    registry  不改    B-5  不动    T-15  NOT_IDENTIFIABLE
```
