# REDTEAM 审计裁定 · registry v1.4.0 立册核验 · 交接口诀 v1.0.0

> 审计对象：`解读registry_risk_typology_v1_4_0.txt`（3,976 行／147,773 字节／MD5 `d27718b6b9e56e856f0a645f89996c1c`／UTF-8·CRLF）
> 对照实档：`registry_risk_typology_v1_4_0.yaml`（1,273／49,447／`fa8a6d28de29529dd6dcbfde75a67cd7`）＋ `.csv`（67／49,278／`497dd8f22efa521d85e1daeb990911c1`）

---

## 甲、审计结论

附件三轮裁定**全数逐条对档复核**，事实引用无一虚构（`admit_to_control`、`category: 内控·非会员风险`、Q-02、S2 PARTIALLY CLOSED、139 日、B-11 `OPEN·随窗口复检`——皆实档原文）。十处修正建议**全采**，无一驳回。

**但附件漏掉了一处比它所列十处都严重的缺陷，本次审计新立：**

### 🔴 SC-25（本轮自认，最高优先）：v1.4.0 YAML 判据层未迁移，双档在判据层分叉

| 层 | CSV v1.4.0 | YAML v1.4.0 | 判定 |
|---|---|---|---|
| 类级字段（四层／双轴／准入） | ✅ 已迁 | ✅ 已迁 | 一致 |
| 判据层 `criterion_role` | ✅ 66 行俱全 | ❌ **不存在** | **分叉** |
| 判据层 `threshold_status` | ✅ 四枚举 | ❌ **仍 35 种中文自由文本** | **分叉** |
| 判据层 `threshold_note` | ✅ 原文全迁 | ❌ **不存在** | **分叉** |
| 判据层 `direction` | ✅ 仅方向行非空 | ❌ **十三值域原样未清** | **分叉** |

**成因**：生成脚本只对 `typologies[].` 类级键写入新字段，未下沉至 `typologies[].criterion_columns[]`。
**更严重的是校验器盲区**：R3／R4／R5／R6／R7 五项**只读 CSV**，故 25/25 全 PASS 是**真实的、但覆盖不全的** PASS——正是「校验器报错时须先校验校验器」之反面：**校验器不报错时，更须校验校验器**。附件之所以仍看见中文 threshold_status，不是它读错版本，是它读的正是 YAML，而 YAML 确实没迁。

**后果范围**：`registry_load()` 以 YAML 为主档，故 R 侧读到的判据层仍是 v1.3.0 语义；下游若写 `direction != ""` 即会把 ref／join／filter 十类当统计方向——附件第四节所警之事，在 YAML 侧**当下即真**。

---

## 乙、v1.5.0 补丁清单（P0 → P1，编号承附件）

**P0·必修**

| # | 项 | 内容 |
|---|---|---|
| P0-0 | **SC-25 双档归一** | 判据层下沉 `criterion_role`／`threshold_status`（四枚举）／`threshold_note`（原文一字不删）／`direction`（非 STAT_DIRECTIONAL 清空）；校验器同步扩为**双档双跑**，R3–R7 各出 YAML／CSV 两份读数 |
| P0-1 | `unlock_predicate` 补 `causal_status` | 加 `AND type.causal_status == 'ESTABLISHED'`——四层铁律写了 L3，谓词却跳过 L3，属自我不一致，附件判「本版最重要的逻辑性补丁」，采 |
| P0-2 | `criterion_role_enum` 顶层定义 | 现 `invariants` 只是**计数约束**，非 **schema 约束**；十枚举须各带 description |
| P0-3 | `direction_rule` 机器门 | `STAT_DIRECTIONAL: REQUIRED；all_other_roles: MUST_BE_NULL`，升 R4 铁律 |
| P0-4 | `threshold_status_enum` 顶层定义 | 四枚举正式化；**采附件语义、留本册命名**——`PENDING_INVERSE`(36)／`NO_THRESHOLD_BY_DESIGN`(22)／`BLOCKED`(7)／`NOT_APPLICABLE`(1)，与附件 DERIVE_REQUIRED／FORBIDDEN／NOT_APPLICABLE／ADAPTIVE 立映射表，不双轨命名 |
| P0-5 | 四层状态枚举全 schema 化 | `phenomenon_status_enum`／`label_validation_status_enum`／`causal_status_enum`（含 ESTABLISHED／TESTED）／`admission_status_enum` |

**P1·下轮执行前必锁**

| # | 项 | 内容 |
|---|---|---|
| P1-1 | `registry_counts` 双维计数 | `risk_types 15 ／ risk_criteria 65 ／ value_axes 1 ／ all_registered_criteria 66 ／ all_registered_objects 16`——防程序误读（caption 已防人工误读） |
| P1-2 | T-10 `type_class` | 采附件之意、**驳其字面**：不设 `risk_typology=false`（会与 `risk_typology_count=15` 打架，且 15 类之数已在三处立册），改设 `type_class: INTERNAL_CONTROL`，与 `lifecycle_state: INTERNAL_CONTROL` 呼应；15 类之数不动，改由 `registry_counts` 加一行 `member_risk_types: 14` 明示 |
| P1-3 | `blocker_class` 四枚举 | `PERMANENT／DATA_GAP／METHODOLOGY／WINDOW_RECHECK`；B-11 归 WINDOW_RECHECK——防「BLOCKED(B-11) ⇒ T-05 永久禁评分」之误读 |
| P1-4 | 下游 NULL 语义护栏 | `UNKNOWN + BLOCKED` 不得被 SQL 当 FALSE（附件第八节）——立明文并入 `global_prohibitions` |

**P2·数据工程主线**：B-02 R03b 截断／B-03 IP 口径／B-04 bet09 拆玩法／B-05 代理链归因／B-06 设备指纹／B-07 下注延迟／B-08 时区／B-09 PIT 限红／B-10 生命周期窗口。

**永持 UNKNOWN 不得顺手修**：Q-01 持牌辖区／Q-02 S05 正例数三版身份（255·124 vs 251·252·125）／Q-03 三种套利模式官方定义／Q-04 P01A-contract-2。

---

## 丙、状态裁定（覆盖上一轮）

> **REG-v1.4.0 = ACCEPTED AS CONTROL BASELINE / NOT SCHEMA-FINAL；且因 SC-25，YAML 侧判据层判 NOT-MIGRATED。**
> ⛔ 实验注册**暂缓**至 P0 全修、双档双跑复验通过。上一轮「可进实验注册」之批准，因 SC-25 撤回。

---

## 丁、交接口诀（下一对话开场即贴）

### 一句话定位
**A168 十五类风险会员分型：登记册是唯一控制平面；证据、标签、因果、准入四层不得串线；十六个登记对象一律禁止处置。**

### 五句铁律口诀

> **一册为宗，双档同行**——登记册 YAML＋CSV 唯一真相源，一动俱动，判据层亦然（SC-25 之教训）。
> **四层不串，逐层举证**——OBSERVED ≠ 已验标签 ≠ 因果成立 ≠ 准入处置。
> **双轴不压，状态并存**——生命周期（SHADOW／PROFILE／FATAL／INTERNAL）× 阻断门禁（UNBLOCKED／BLOCKED）互不吞并。
> **五门未开，十六皆锁**——G01 FAIL·G02 FAIL·G03 PARTIAL·G04 现算·G05 FAIL；`admit_to_risk_decision = FALSE × 16` 无例外。
> **不知照登，废者不复**——UNKNOWN／OPEN／BLOCKED 是可审计状态不是待填空白；SUPERSEDED 证据永不满足 TESTED_PASS，T-03 永不复活。

### 数字口诀（背下即可自查）
**15 类 ＋ 1 轴 ＝ 16 对象；65 判据 ＋ 1 判据 ＝ 66 登记判据；角色十枚举，方向占四十二；阻断十一项，引用十一（B-11 已回挂）；评分面四（T-04·T-05·T-08·V），处置面零。**

### 三类特例口诀
**T-03 —— 四证已伪，画像可留，排序评分触发处罚皆禁，改名重组亦禁。**
**T-10 —— 恒等对账，内控独轨，非会员风险，永不入风险评分。**
**T-04·T-05·T-08 —— 影子可入，处置不可；主表未取，证据在册 ≠ 表已备。**

### 下一对话首件事（按序）
1. 出 v1.5.0 双档，先修 SC-25＋P0 五项；
2. 校验器扩为**双档双跑**，R1–R25 每项各出 YAML／CSV 两读数；
3. 复验通过再立六元组、旧档 `_superseded`、改 `配置/paths_a168.R` 指针；
4. 之后方谈实验注册（T-04／T-05／T-08 对 L1a 之影子量测预注册），实验之后方写 SQL。

### 归位口诀
**登记册与变更单归 `规范/`，分析包规格自立 `分析/`，工单与内容稿随评估档，旧版一律 `_superseded` 不删；盘上档名唯点号（v1.5.0），下划线仅上传通道所致。**
