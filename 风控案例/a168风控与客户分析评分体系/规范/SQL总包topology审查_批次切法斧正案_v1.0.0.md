# SQL 总包 topology 审查 · 批次切法斧正案 v1.0.0

**日期**：2026-08-23　**置放**：`审计/`　**ARTIFACT CLASS**：`A3 WORKING_DRAFT`
**canonical**：`false`　**受检件**：`a168_取数与核验_SQL总包_v11.0.1.sql`
**分支**：`v11.0.2-WIP`（只读审查，不改 canonical）

---

## 〇、受检件身份（三锚全中）

| 锚 | 实测 | 在册 | 判 |
|:--|:--|:--|:--:|
| MD5（原样 CRLF） | `0ca299179ba3ad478443c5b58b08b8d6` | 同 | ✅ |
| MD5（LF 归一） | `9400ae862e76c92c1d3088d8696243d8` | 同 | ✅ |
| MD5（纯代码） | `ce768c35b8d7aeb5ac28079166a8c422`／5,961 行 | 同 | ✅ |
| 行数 ／ 字节 ／ 换行 ／ 编码 | 10,373 ／ 1,306,165 ／ CRLF ／ UTF-8(no BOM) | 同 | ✅ |

**三层身份（承 `VERSION-META-01`）**：`Release ID` 待补登 → `REL-0003`；`Contract ID` → `C1`；`Implementation version` → `v11.0.1`。

---

## 一、一处撤回 ＋ 一处补注 ＋ 一处隐患登记

### 撤回 W-7（我方 · 同类第三犯）

前判「纯代码 MD5 锚无法复现」——**不成立，撤回**。
成因：**我漏了剥块注释**，径以行注释剥法重算，故得 8,999 行而非 5,961 行。
`R4-SEMANTIC-02` 甫经批准，我自己先违一次：**未验规则即断其不可复现**。

### 补注 SC · 萃取规则记述不完整（弱化后仍成立之点）

卷首第 34 行仅书「**剥离行尾注释后**」，**未提块注释**。
第三方照字面复现必失败（我即为实例）。**须补注完整规则，非改锚值**：

```
① 以正则 /\*.*?\*/（非贪婪、跨行）剥去块注释
② 按行切（CRLF 或 LF 皆可，结果同）
③ 剥去 '--' 起之行内注释
④ 逐行 rstrip
⑤ 弃空行
⑥ 以 LF 连接
⑦ UTF-8（无 BOM）编码后取 MD5
```

**此规则为 `VERSION-META-02` 之 PATCH 判据基础**——规则不完整，PATCH 判定即不可复核。

### 隐患登记 · 块注释标记失衡

`/*` 出现 **224** 次，`*/` 出现 **223** 次；剥配对后余 0。
→ **有一个 `/*` 嵌于块注释内部**。多数 SQL 引擎块注释不嵌套，故**当前无碍**；
惟若日后经支持嵌套之解析器处理，将当场错位。**登记为潜在风险，本轮不改。**

---

## 二、结构侦测：本包**不是函数库**

| 探测项 | 实测 |
|:--|--:|
| `CREATE FUNCTION` | **0** |
| `CREATE VIEW` | **0** |
| `CREATE TABLE` ／ `TEMPORARY` | **0** |
| `INSERT INTO` | **0** |
| `PREPARE` ／ `SET @` | **0** |
| 剥块注释后语句数 | **197** |
| 含 `SELECT` ／ 含 `WITH` | 177 ／ 75 |
| 唯一 CTE 名 ／ CTE 定义次数 | **16 ／ 75** |

**CTE 名重复度**：`ta` 25 次、`test_agents` 19 次、`ranked` 6 次……

> **同名 CTE 在各语句内各自重复定义，彼此不共享。**
> 此系纪律①「每条查询自包含、零占位符——整段复制直接运行」之必然结果，非缺陷。

**结论：本包系 197 条彼此独立、各自自包含之查询序列，非函数库、非程序。**

---

## 三、原拟六批之四批在本包内不存在

| 原拟批 | 实况 | 判 |
|:--|:--|:--|
| **A** 公共 CTE ／ loader ／ source ／ registry | 无公共 CTE（逐语句重复定义）；loader 在 `函数/registry_loader.R`；registry 在 `规范/*.yaml`＋`*.csv` | **空批** |
| **B** member ／ wallet ／ bet ／ account 函数 | 无函数，只有内联查询 | **空批** |
| **C** 十五类风险函数 | 无函数；且十五类未逐类成段 | **空批** |
| **D** metric ／ ROI ／ AVG ／ RATE 统计函数 | 无函数，指标皆内联表达式 | **空批** |
| **E** 输出表 ／ schema ／ export ／ validation | 有——`▸ 导出` 声明散于各段 | 部分成立 |
| **F** registry 调用与映射 | 本包不调 registry；映射在 `配置/paths_a168.R` 与 loader | **空批** |

**若照原六批切，A／B／C／D／F 五批将贴出空壳或错配之内容。**

---

## 四、依实际结构之批次切法（本册所荐）

本包实有 **178 个唯一段号**，归 **30 个段族**。按族与职能重划六批：

| 批 | 段族 | 段数 | 职能 | 首要审查点 |
|:--|:--|--:|:--|:--|
| **A · 卷首与纪律层** | 卷首块注释（1–435 行）＋ `§Z`（22） | 23 | 版本身份、窗口、常数登记、血统、注释体例、变更记录 | 常数处数是否现算；窗口两端字面量；`§Z-16` 变更记录完整性 |
| **B · 结构探查层** | `§EX`（47）＋ `§DX`（6）＋ `§BZ`（2） | 55 | 表结构、列义、字段语义实测 | **`dt` 语义是否逐表定谳**（`R4-SEMANTIC-01`） |
| **C · 实体与口径层** | `§B01`／`§P11`／`§P12`／`§P13`／`§V`／`§A` | 16 | 会员域、总帐、入场行为、维度字典 | **grain → entity key → join key → denominator** 四问 |
| **D · 风险判据层** | `§R01`(8)／`§R02`(4)／`§R03`(6)／`§C06`／`§T02`／`§T03`／`§K01`(3)／`§S04` | 30 | 各风险类型之取数 | **十五类之 grain 是否逐类锁定**；`ROI`／`AVG`／`RATE` 之式是否按 grain 分立 |
| **E · 经济与处置层** | `§E02`(4)／`§ECON`／`§TL`(20)／`§TZ`(7) | 32 | 单位经济学、处置台账、时区 | **`ROI` 分母**；`§ECON` 三分律；处置事件 grain |
| **F · 泄漏与验证层** | `§P0C`(11)／`§TG`(4)／`§PIT`／`§C`／`§D`／`§F`／`§RC` | 22 | 穿越检测、泄漏矩阵、越界自检 | **target leakage 门禁**（承 `alarmMessage.type` 之裁示） |

**次序理由**：A → B 先把「表是什么」定死（`dt` 语义、列义），C 再定「实体与键」，
D／E 才谈判据与指标，F 收口于泄漏验证。
**恰为裁示所锁之六级门**：`grain → dt semantic → entity key → join key → denominator → metric`。

---

## 五、每批之只读审查表（不改原 SQL）

逐段填，不跳级：

```
段号
 ├─ SOURCE          取自哪张表
 ├─ DT SEMANTIC     该表 dt 系 snapshot ／ registration ／ event？（R4-SEMANTIC-01）
 ├─ GRAIN           一行代表什么
 ├─ ENTITY KEY      实体主键
 ├─ JOIN KEY        与他段之连接键
 ├─ DENOMINATOR     若含比率，其分母为何、零分母如何处置
 ├─ METRIC          所出指标及其式
 ├─ OUTPUT SCHEMA   ▸ 导出声明、列集、下游 must=
 └─ 处置建议        保留 ／ 重构 ／ 拆分 ／ 参数化 ／ 新增 ／ 废弃
```

**审毕方决定哪些指标可真正进入 `registry_risk_typology_v1.5.0`。**

---

## 六、三条须先立之指标层门禁（承裁示第六至九节）

### G-METRIC-01 · 指标是 topology 之函数，非其定义

> **禁反向而行**：先算 `ROI`，再找它是什么意思。

### G-METRIC-02 · 六元定义，缺一不得入册

```
metric_name ／ metric_formula ／ metric_grain ／
metric_denominator ／ metric_window ／ metric_source ／ metric_status
```

且每类须各有：`allowed_metrics` ／ `required_metrics` ／ `forbidden_metrics` ／ `denominator` ／ `grain`。

> **「函数存在」≠「该风险类别允许使用」。**

### G-METRIC-03 · `EXPLORE`／`RAMP` 只得登记为**指标族**，禁擅冻数学式

`EXPLORE` 至少可指：荷官探索／台桌探索／玩法探索／注型探索／时窗探索
`RAMP` 至少可指：注额爬升／频次爬升／追损爬升／强度爬升

**topology 未定前，二者仅登记为 `metric family`。** 此系 `R4-SEMANTIC-01` 在指标层之延伸。

### G-LEAK-01 · target leakage 全局门禁（自 T-03 之教训升格）

```
候选 label → 时间独立性检查 → 行为触发关系检查 → target leakage 检查
           → 人工／外部定义验证 → 方可成为 label
```

**禁**：行为 → 触发系统告警 → 拿告警当 label → 再用同一行为预测告警。
即 **答案预测答案**。`alarmMessage.type` 现为 `LABEL CANDIDATE`，**非 GOLD LABEL**。

---

## 七、当前状态

```
canonical              v11.0.1  LOCKED
三层身份                REL-0003 ／ C1 ／ v11.0.1
分支                    v11.0.2-WIP（只读审查）
topology               NOT MODIFIED
registry v1.5.0        LOCKED

P-H0                   CLOSED · H-AXIS = H_PARTIAL
R4-SEMANTIC-01/02/03   APPROVED · GLOBAL
VERSION-META-00~03     APPROVED
本册                    A3 WORKING_DRAFT · 待裁批次切法
```

**待裁一句**：批次切法采本册第四节之 A–F，抑或另拟？
裁定后即自 **批次 A（卷首与纪律层）** 起，逐批出只读审查表。

**全程不改 canonical，不产出任何 SQL 变更。**
