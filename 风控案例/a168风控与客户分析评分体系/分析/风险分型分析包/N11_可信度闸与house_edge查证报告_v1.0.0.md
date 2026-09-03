# N-11 · 交付件可信度闸之立 · `house_edge` 查证 · 参考稿红队校对

- 版本 : 1.0.0　日期 : 2026-09-03　撰者 : Ryo（雷欧）
- 承 : 先生「先修广播」之令、`house_edge` 之直问、及《参考.txt》红队稿之校对。
- 铁律 : NOT_RUN ≠ PASS；NULL ≠ 0；UNKNOWN ≠ FAIL；只优化强化升级，禁退化。

---

## 一、先答直问：P5D 有哪些表包含 `house_edge`

### **答：一张也没有。**

全包机检，`house_edge` 命中 **2 处，且两处皆在注释内**：

| 行 | 原文 |
|---|---|
| 86 | `house_edge = NULL · theo = NULL。` |
| 146 | `阻断原因二：bet09 → house_edge 映射值未获授权…` |

**无任何 `CREATE`、`SELECT ... AS house_edge`、`INSERT` 或输出列。**
另查 `edge_*` 之 22 处命中，实测**全数为 `hedge_*` 之子串**（`hedge_coverage` / `hedge_pairs` /
`hedge_rate`），系我方 grep 误配，**全包确无 edge 概念**。

### 1.1 该不该补？——**该补，然补前有两道非工程之关口**

总包档头（行 138–152）自陈 F-22~25 三条阻断因由，逐条查实：

| # | 阻断因由 | 性质 | 可否由重导解决 |
|---|---|---|---|
| 一 | `#075` 之 `x_agg` 已把产品维折叠，仅存 `common_product_count` 与结构熵，无 `bet09` 级 `valid_bet` 分解 | **工程** | ✗ 须新增「会员 × 产品」之 `x_prod` 中间粒度 CTE |
| 二 | **`bet09 → house_edge` 映射值未获授权** | **业务授权** | ✗ 非数据问题 |
| 三 | 施加范围（四实体件 8 处 vs 全模板 256 处）未获裁示 | **裁定** | ✗ |

而且总包另载一条**更硬之实测**（行 148–151）：

> `#017` 探针 R3 实测 overdispersion `Q/(k−1) = 9.3 ~ 42.6`（Banker/0 = 42.6、Player/0 = 40.8）
> ⇒ 单一 `(bet09 × commission_flag)` 常数 edge **不足以描述观测过程**：
> **KILL single-constant-edge architecture**。

⇒ 即：**纵使明日授权了 edge 值，单一常数 edge 亦已被实测否决。**
新架构须为 `bet09 × regime × time × table(-group)`。

另实测：`free_comm_rate > 0` 者 **70,024 名（9.68 %）**、`= 1` 者 **20,629 名（2.85 %）**，
免佣桌规则不同 ⇒ 映射表主键须为 **`(bet09, 免佣标记)` 二元**。

### 1.2 补法（承《参考.txt》第八节，此点其言甚是）

⛔ **绝不可为求 `theo` 而把 `house_edge` 广播到 133 张表** —— 那将亲手打破刚立之广播闸。

正解为三层：

```
第一层 SSOT     bet09_house_edge_registry(bet09, 免佣标记, regime, edge, 生效起, 生效迄, 版本)
第二层 中间粒度  x_prod : member × bet09 × 免佣标记 → valid_bet 分解
第三层 会员商业表 只出 theo / adt / nmpt / esi，不出 house_edge
```

---

## 二、关于「先修广播」：**SQL 侧已修好，未修者在我方**

### 2.1 SQL 侧：D-14 斧正已在 P5D 完成

总包档头第 5 行即：

> `★★ HF9g-P5 · D-14 斧正（全窗基线族之六层退化）· Ryo Eng 授权 2026-08-29 ★★`

其定性（行 11）：

> 真正的病灶是：六层商业模板被机械套在**全窗基线族**上，而六层之相对刻度须逐实体，不可施于常数。
> `NTILE(5) OVER (ORDER BY 常数)` ⇒ 全行同档；`PERCENT_RANK() OVER (ORDER BY 常数)` ⇒ 恒 0；
> `action_priority` 之 `<=0.10` 分支恒真 ⇒ 全件 **100 % 误标为「A」**。

处置：`x_win` 族 **66 件**之六层十二列一律改 `CAST(NULL AS …)`，
`action_priority` 改 `'X 全窗基线 · 不参与实体赏罚'`。

⇒ **「修广播」与「重导 P5D」实为同一件事**：SQL 已改，只待重导落盘。
盘上 130 件仍是 P4D 产物，故仍带「常数误值」。

### 2.2 我方侧：可信度闸从未接线 —— **本轮最重之自陈**

总包档头另载一份**逐件可信度清单**（133 行，定长格式，机器可解析）：

| 级 | 件数 | 含义 | 用法 |
|---|---|---|---|
| **OK** | **24** | 连接 1:1，本行金额即本行事实 | 可直接做商业判定 |
| **WRONG_GRAIN** | **37** | e 侧按上层粒度连接，金额于多行重复 | 仅作背景，勿算比率 |
| **INVALID** | **67** | `CROSS JOIN x_agg` 笛卡尔广播，值不相干 | 勿用 |
| NULL | 1 | `#079` 跨实体未命中 | 只看前 7 列 |
| N/A | 4 | 三字典 ＋ `#133` | 本无六层块 |

24 ＋ 37 ＋ 67 ＋ 1 ＝ 129；加 4 ＝ **133，逐条闭合**。

⛔ **本引擎 1.7.0 及以前从未读过此清单。** 其广播侦测只验「逐行同值」（`uniqueN <= 1`），
该法**只抓得住 67 件 `INVALID`，37 件 `WRONG_GRAIN` 全数漏网**：
上卷广播之值在多行重复而非全表同值，相异值数 > 1，遂通过检验，随后被当作逐行实体金额入账。
**此即「看起来完全合理」之最危险一类。**

**处置**：已提取清单为 `规范/deliverable_credibility_v1.0.0.csv`（机器解析，非手写），
引擎 1.8.0 新增 §12：`tr_credibility()` / `tr_money_admissible()` / `tr_credibility_panel()`，
并于 `tr_economic_profile()` / `tr_criterion_exposure()` / `tr_signed_ladder()` 三处入口加闸。
**实体级金额只准取自 `OK` 件**；`UNKNOWN ≠ PASS`，不在清单者亦拒。

---

## 三、加闸后之回溯：前两轮 53 条判据暴露，**仅 17 条存活**

| 可信度 | 条数 | 处置 |
|---|---|---|
| **OK** | **17** | ✓ 存活 |
| WRONG_GRAIN | 28 | ⛔ 撤回 |
| INVALID | 8 | ⛔ 撤回 |

### 3.1 存活者（实体金额准用）

| 类 | 判据 | 源表 | 尾部 | hold 倍数 |
|---|---|---|---|---|
| **T-07** | **投注产品结构熵** | `S01_player_score` | ≤P10 | **3.744** |
| T-03 | shoe_pos_p50 | `R01_late_shoe` | ≥P90 | 1.445 |
| T-05 | hedge_rate | `T03_arbitrage` | ≥P90 | 1.335 |
| T-06 | share_p90 | `I_ip_agg` | ≥P90 | 1.283 |
| T-06 | n_member_raw | `I_ip_agg` | ≥P90 | 1.212 |
| T-02 | 特定玩家复现率 | `S02_dealer_score` | ≥P90 | 1.110 |
| T-06 | n_member_eff | `I_ip_agg` | ≥P90 | 1.093 |
| T-09・T-11 | member_per_chain | `C01_ip_chain` | ≥P90 | 1.091 |
| T-03 | stake_ramp | `R01_late_shoe` | ≥P90 | 1.081 |
| T-02 | 节奏稳定度 | `S02_dealer_score` | ≥P90 | 1.050 |
| T-03 | tail_share | `S_player_tail` | ≥P90 | 1.042 |
| T-15 | span_days | `S01_player_score` | ≥P90 | 0.942 |
| T-15 | 生命周期阶段 | `S01_player_score` | ≥P90 | 0.922 |
| T-03 | late_share | `R01_late_shoe` | ≥P90 | 0.898 |
| T-05 | stake_cv | `T03_arbitrage` | ≤P10 | 0.732 |
| **T-07** | **索提诺稳定性** | `S01_player_score` | ≥P90 | **0.252** |

⇒ **二处头条结论皆建于 `S01_player_score`（`OK` / `PRIMARY` / 会员 / `member_id`），安然无恙。**
`N-10 §三` 之有符号阶梯（4,973 人贡献 94.86 % 净 NGR；21,549 人吃掉 48.79 %）亦同源，同样有效。

### 3.2 撤回者（前两轮曾引用，今拒出）

| 类 | 源表 | 级 | 撤回判据 |
|---|---|---|---|
| T-01 | `R02_same_table`（粒度 `uid1 × uid2` 之**对**） | WRONG_GRAIN | lift、jaccard、same_rate、exp_same、n_tables |
| T-04 | `C06_hedge_pairs` | WRONG_GRAIN | opposite_rate、n_opposite_round、hedge_coverage 等 6 条 |
| T-05・T-07・T-12・T-13 | `K01_risk_feature_matrix` | WRONG_GRAIN | rebate_dep、side_entropy、stake_p90_p50、night_share 等 |
| T-08 | `E02_segment_econ` | **INVALID** | reb_k、comm_k、rebate_rate_bkt |
| T-08・T-09 | `S03_agent_score` | **INVALID** | 退水消耗比、新增会员质量、下线留存、真实流水 |
| T-08・T-15 | `S05_member_month_panel` | WRONG_GRAIN | 退水支出、活跃稳定、流水贡献、n_ip |
| T-06・T-11 | `I_ip_player` | WRONG_GRAIN | ip_order_share、n_orders_ip |
| T-12 | `X_combo` | INVALID | progress |

⇒ **T-01、T-04、T-08、T-10、T-12、T-13、T-14 七类，现无任何可信之经济暴露。**
仅 **T-02、T-03、T-05、T-06、T-07、T-09、T-11、T-15 八类**有实体金额可读。

### 3.3 ⛔ 一项须撤回之前轮论断

前轮我曾以「五级代理各级洗码合计皆为 12,101.5M，与 S01 吻合」为据，称**代理树为完整分割**。
**此论应撤。** `S03_agent_score` 之可信度为 **`INVALID`**、粒度为 **`b.lv3`**、用法 `NOT_FOR_DECISION`。
金额总量吻合可能仅反映同一平台合计被各层重复携带，**不足以证明逐层无重复归属、无孤儿、无多父**。
《参考.txt》第八节指此点，其言甚是，本轮采纳并撤回原论断。

---

## 四、《参考.txt》校对：采纳、修正、与不同意之处

### 4.1 采纳（其言甚是）

| 条 | 内容 | 本轮处置 |
|---|---|---|
| RT-01 | 测试线须在统计**之前**隔离 | 已以**行号**证之，见 §五 |
| §七 | 跨源金额之 grain 与扇出风险 | **正中要害**，即本轮可信度闸所治，已立 |
| §八 | 五级代理金额吻合不足以单独证明分割完整 | **采纳，已撤回原论断** |
| §十 | 不因经济结果反改 `direction`，另立 `economic_polarity` | 采纳，列入下轮 |
| §九 | `hold 倍数` 须锁分母口径 | 采纳；本引擎实为 `(尾部 NGR ÷ 尾部洗码) ÷ (全表 NGR ÷ 全表洗码)`，已于报表明书 |
| §三 | 100 % 尾部应升为机器可读状态而非仅书「退化」 | 采纳，列入下轮 `criterion_status` |
| §五 | `>=` 与 `>` 之 tie semantics 须落盘 | 采纳，列入下轮 |
| §六 | 65 条判据须逐条闭合回收 | 采纳，列入下轮 |
| 二稿 §三 | 零点系质量点，不作普通分位，只报 `zero_n` / `zero_rate` | **本轮已实作**（引擎 §11 三段质量） |
| 二稿 §四 | 15 指标不可机械套双尾 | **本轮已实作**（`.TR_NULL_REFUSE` 明令拒算四族） |

### 4.2 修正其稿（其未及查证之处）

| 稿中所述 | 实况 |
|---|---|
| 「不能诚实声称已查完 P5D…`house_edge` 尚不能证明」 | 本轮已查：**2 处命中，皆注释；零表输出**。且 `#017` 实测已 KILL 单一常数 edge 架构 |
| 「先修广播，再重导」为两步 | **实为一事**：D-14 已在 P5D 修好，只待重导 |
| 未提及总包自带 133 行可信度清单 | **此清单才是广播治理之真正抓手**，本轮据以立闸 |
| 「广播常数仍可作 benchmark / denominator」 | 部分成立，然须限缩：`x_win` 族之六层列系 `NTILE/PERCENT_RANK` 施于常数之**退化产物**，非有效基线，P5D 已一律改 NULL |

### 4.3 一项须修正之建言（我方前轮之误）

我前轮建言「**求单位服务成本 C 应列最高优先**」。
查总包档头行 145：

> `F-26 绝对金额阈值 —— 不授权由数据反解。须先定优化目标（ΔP&L）与训练/验证/walk-forward/成本四项，否则不动。`

⇒ **C 不是测量问题，是业务输入问题。** 重导 P5D **不会**产出 C。
我前轮之表述有误，当正：C 须先生**给定**，非我方反解。

---

## 五、测试线闸位：以行号证之

《参考.txt》列此为第一杀点。我曾做污染注入测试，**然该测试偏弱**——
两侧皆手算真实子集，故不变属必然，不足为证。真正之证据是**模板内 `ld` 之生命史行号**：

| 行 | 语句 |
|---|---|
| 226 | `ld <- tr_load_all(rec)` |
| **277** | **`ld <- tr_drop_testline(ld)`** |
| 286 | `cs <- tr_criterion_stats(rec, ld)` |
| 311 | `ep <- tr_economic_profile(rec, ld)` |
| 341 | `ce <- tr_criterion_exposure(rec, ld)` |
| 427 | `tr_signed_ladder(...)` |
| 446 | `mj <- tr_member_join(rec, ld)` |
| 453 | `cm <- tr_corr(mj$panel)` |
| 772 | `pc <- tr_pca(mj)` |

⇒ **一切统计皆在 277 行之后**，血统为 `RAW → LOAD → TESTLINE GATE → statistics`。**PASS。**

另注：唯一带测试线之交付件 `S03_agent_score` 其可信度为 `INVALID`，
故其测试线风险已不涉实体金额，只涉判据分位。

---

## 六、重导 P5D 究竟会改变什么（务请先生留意）

| 项 | 重导后 |
|---|---|
| `x_win` 族 66 件之六层十二列 | ✓ 由「常数误值」变 `NULL`（真改善，除误导） |
| `action_priority` | ✓ 由 100 % 误标「A」变「X 全窗基线 · 不参与实体赏罚」 |
| `x_agg` 族 62 件 | — 逐位不变，无须重导 |
| **24 / 37 / 67 之可信度分级** | ✗ **不变** —— 系连接**粒度**之结构，D-14 不动之 |
| **`house_edge` / `theo` 族** | ✗ **不会出现** —— 全包无此栏，且须业务授权 |
| **单位成本 C（F-26）** | ✗ **不会出现** —— 明令不授权由数据反解 |

⇒ 重导**值得做且应当做**（除去 66 件之误导常数），
但**不会**解开 theo 族与 C。此二者须先生之授权与给定，非重导可致。

---

## 七、本轮落盘

| 件 | 版本 | 说明 |
|---|---|---|
| 函数/typology_report_engine.R | 1.7.0 → **1.8.0** | 新增 §12 可信度闸 |
| 模板/风险会员商业方案_模板.qmd | 1.6.0 → **1.7.0** | 新增「〇之三 可信度闸」章；阶梯补传 `file=` |
| 函数/build_typology_reports.R | 1.3.6 → **1.3.7** | 默认版 v1.7.0 |
| **规范/deliverable_credibility_v1.0.0.csv** | 1.0.0（新） | 133 行，自总包档头机器解析 |
| 审计/判据暴露_可信度加闸_v2.0.0_20260903.csv | 2.0.0（新） | 53 行，含撤回理由 |

---

## 八、待先生裁定

1. **是否授权 `bet09 × 免佣标记 × regime → house_edge` 映射值**。此为 theo 族唯一钥匙，非工程可代。
2. **是否给定单位服务成本 C**（F-26 明令不得由数据反解）。
3. **是否新建 `x_prod`（会员 × bet09 × 免佣）中间粒度 CTE**。此项纯属工程，可即办。
4. **重导 P5D 之时点**。SQL 已备，验收判据总包自载三条：
   ① `action_priority` 唯一值恒为「X 全窗基线 · 不参与实体赏罚」；
   ② 六族列全为 NULL；③ 其余业务列与 P4 逐位相同。
5. 下轮 N-12 之四事：`economic_polarity` 另立、`criterion_status`（ACTIVE/DEGRADED/COLLAPSED）、
   tie semantics 落盘、65 条判据逐条闭合。
6. git commit 仍未执行。
