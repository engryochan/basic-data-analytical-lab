# B-6 · REFUTED 隔离规格 v1.0.0

**日期**：2026-08-23　**置放**：`规范/`　**ARTIFACT CLASS**：`A3 SPEC`　**canonical**：`false`
**上游**：`Z2-08`（REFUTED 禁复活之机械禁令，已入 `v11.0.3`）／`G20`（REFUTED 隔离闸，C2 待建）
**阻断**：**B-6** —— 裁示定「可立即裁定，无需等待全部 A–F」

> 本规格属**规范层**，`v11.0.3` 已具其原则（`Z2-08`）；本册只把该原则**执行化**，
> 定其在 v12 之 SQL 与输出层如何落地。**不改 `v11.0.3` 一字。**

---

## 一、裁定

$$\text{REFUTED 类之判据}\;\longrightarrow\;\textbf{可入 SQL，但只得进 PROFILE\_ONLY 层}$$

**准**：产出**档案列**（descriptive column），供研究、复盘、对照。
**禁**：产出**触发列**（trigger）、**处置列**（enforcement）、**商业名单列**（eligibility）。

### 三态之别（禁互代）

| 层 | 问什么 | REFUTED 可否 |
|:--|:--|:--:|
| PROFILE | 此会员之行为长什么样 | ✅ 可 |
| TRIGGER | 此会员是否应被标为风险 | ❌ 禁 |
| ENFORCEMENT | 此会员是否应被处置 | ❌ 禁 |
| ELIGIBILITY | 此会员是否进商业名单 | ❌ 禁 |

---

## 二、落地三条

### 其一 · 输出须携标记列，不得裸出

凡 REFUTED 类之任何列，其所在输出**必须**同行携带：

```
criterion_status      = 'REFUTED'
label_validation      = 'REFUTED'
causal_status         = 'REFUTED'
admit_to_risk_decision = FALSE
refuted_at            = <证伪日期>
refuted_evidence      = <四项独立验证之编号>
```

**裸出 REFUTED 列而无标记者，判 S1。**
理由：下游拿到一列 `late_share` 而不知其已被证伪，必当作有效判据用——
**证伪之知识若不随数据流动，等于没有证伪。**

### 其二 · 物理隔离，非仅逻辑标注

REFUTED 类之输出**不得**与 ACTIVE 类混于同一交付件。
须另出独立文件，档名带 `_refuted_profile` 后缀，例如：

```
数据库/R01_late_shoe_refuted_profile.csv        ← REFUTED 档案
数据库/…（ACTIVE 类之交付件）                     ← 不得含 REFUTED 列
```

理由：逻辑标注可被 `SELECT *` 一笔抹去；**物理隔离抹不掉**。
承既有教训——`Z2-03` 之 YAML／CSV 双重真相，正是「逻辑上说了、物理上没拦」之实例。

### 其三 · 下游 `must=` 须明列其禁用

下游三档之 `must=` 清单须为 REFUTED 交付件另立一节，明书：

```
本档系 REFUTED 档案，仅供研究与复盘；
禁作风险判定、禁作处置依据、禁入商业名单。
引用本档之任何结论，须整句连此禁令一并引用。
```

---

## 三、现行 REFUTED 名录（**T-03 一类，2026-08-23 现况**）

| 类 | 判据 | 状态 | 证伪依据 |
|:--|:--|:--|:--|
| **T-03** 尾投／靴尾下注 | `late_share`／`shoe_pos_p50`／`stake_ramp`／`tail_share` | `label_validation = REFUTED`<br>`causal_status = REFUTED`<br>`admit_to_risk_decision = false` | 四项独立验证：<br>符号检验 p ＝ 0.7591<br>Wilcoxon p ＝ 0.8087<br>九分档 hold% 扫描零命中<br>外部 L1a AUC ＝ 0.3828（**方向反转**） |

**AUC ＝ 0.3828 < 0.5 尤须留意**：不只是「无判别力」，而是**方向相反**——
若据以出名单，命中的是与预期相反的人群。此非「弱判据」，系**错判据**。

---

## 四、与 `Z2-08` 之衔接（禁复活五径，原样照录）

REFUTED 者**不得**因下列任一恢复其 `admit_to_risk_decision`：

1. 上游诊断结论改变（粒度、分母、坐标系之澄清）
2. 阈值重选（改 0.80 为他值、改分位为他分位）
3. 子样本、分层、换窗后之显著结果
4. 新增协变量后之显著结果
5. **经济结果层观察到 ROI／GGR 为正**

**唯一可恢复之途**：重跑原四项独立验证且**四项皆翻转**，并另立变更单，
记明四项之新旧读数逐项对照。

> 本禁令之对象是 **REFUTED 之状态**，非某一判据之名；
> 故对 T-03 成立者，对此后任何被判 REFUTED 者同样成立。

---

## 五、G20 闸之判据（C2 层 · 供 v12 施工时机械验收）

```
G20 · REFUTED 隔离闸
  ① REFUTED 类之列不得出现于 trigger／enforcement／eligibility 之任一输出
  ② REFUTED 类之交付件档名须带 _refuted_profile 后缀
  ③ REFUTED 类之每一输出行须携六项标记列，缺一即 FAIL
  ④ ACTIVE 交付件内不得出现任何 REFUTED 类之列
  ⑤ 下游 must= 清单须含 REFUTED 专节及其禁令全文
判 FAIL 即 BLOCK，禁止发布。
```

---

## 六、B-6 解除

```
B-6  T-03 系 REFUTED，其入 SQL 之身份未定
  ↓
本规格裁定：可入 SQL，只得进 PROFILE_ONLY；三条落地；G20 闸判据已定
  ↓
B-6 = 🟢 PASS（俟本册获裁）
```

**余五项阻断状态不变**：

```
B-1 Registry SSOT 强制        🔴 BLOCK（可并行）
B-2 registry_loader 血统      🔴 BLOCK（可并行）
B-3 十五类 grain              🔴 BLOCK（串行 · 依赖 A–F）
B-4 μ0(g,w)                   🔴 BLOCK（可并行 · 工具已出，待跑）
B-5 bet16／validbet 交付      🔴 BLOCK（外部依赖 · 须向数据方取）
B-6 T-03 身份                 🟢 待裁转 PASS
```

**本册不含 SQL，未触 `v11.0.3` 一字。**
