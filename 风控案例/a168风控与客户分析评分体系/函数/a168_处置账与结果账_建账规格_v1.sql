/* ═══════════════════════════════════════════════════════════════════════════
   a168 · 处置账（Treatment Ledger）与结果账（Outcome Ledger）建账规格 v1.0
   ---------------------------------------------------------------------------
   立此规格之由：
     本方案之 P&L Gate 十闸，未过之五闸（Gate 5 处置可执行 / Gate 6 对照组 /
     Gate 7 随机化 / Gate 8 增量 NGR / Gate 10 多周期复制）全部指向同一处缺口——
     **平台没有一条记录能证明「限红、冻结算、追佣金」这些动作真的执行过**。
     CPOS 十二层之第七层（处置引擎）以下六层，亦皆因此而空。

   ★ 一句必须先讲清楚的话（防误解，亦防误期）：
     **这两本账不能由现有数据造出来。**
     它们记录的是「动作」，而动作从未发生过——不存在任何 SQL 能把没发生的事查出来。
     故本文件给的是**账簿的规格与建账手续**，不是账本身。
     账要从「今天起，每做一次处置就记一笔」开始长，别无他法。

   ★ 回填可行性裁定（逐项核实，据实而言）：
     · 处置动作本身            ⛔ 不可回填——无任何留痕
     · 谁在何时对谁做了什么    ⛔ 不可回填
     · 动作之后的业务结果      🟡 可部分回填——注单流水本就在库，
                                 惟须先有「动作发生时点」方能对齐前后窗，
                                 而该时点正来自处置账。故仍以处置账为前置。
     · 历史人工标记            🟡 仅 alert_ip_setting 之 17 条（2022–2025），
                                 且六名标注人中五人最近登记在 2022 年，
                                 可作**起点存量**，不可作处置账之替代。

   ★ 库为只读，本文件之 DDL **不得在 ODS 库执行**。
     其落点为业务侧可写库（或 DolphinScheduler 侧新建库），
     再由既有同步链路以 ods_a168_* 之惯例回流 ODS 供分析侧读取。

   ★ 最小可行起步（不必等系统改造，明日即可开始）：
     第一步只须两张表、十二个必填字段、一个共享表单。
     哪怕先用人工填表、每日导一次 CSV，也胜过等一套系统建成——
     **账早一天开始长，因果证据就早一天可能取得。**
   ═══════════════════════════════════════════════════════════════════════════ */


/* ───────────────────────────────────────────────────────────────────────────
   一 · 处置账 treatment_ledger —— 记「我们做了什么」
   ---------------------------------------------------------------------------
   一行 = 一次处置动作。粒度：动作 × 对象。
   凡对客人、代理、荷官产生任何影响者，一律记一笔；不论人工或自动。
   ─────────────────────────────────────────────────────────────────────────── */
CREATE TABLE IF NOT EXISTS a168_treatment_ledger (
  tl_id            VARCHAR(64)   NOT NULL COMMENT '处置流水号，全局唯一（建议 UUID 或 日期+序号）',

  /* ── 谁、何时 ─────────────────────────────────────────────────────────── */
  decided_by       VARCHAR(64)   NOT NULL COMMENT '决定人工号；自动执行者记 SYSTEM',
  decided_at       DATETIME      NOT NULL COMMENT '决定时刻（下判之时，非生效之时）',
  executed_by      VARCHAR(64)            COMMENT '执行人工号；未执行者留空',
  executed_at      DATETIME               COMMENT '生效时刻——★ 因果分析之事件零点，最要紧的一列',
  reverted_at      DATETIME               COMMENT '撤销时刻；未撤销者留空（可回滚是本方案之处置纪律）',

  /* ── 对谁 ─────────────────────────────────────────────────────────────── */
  entity_type      VARCHAR(16)   NOT NULL COMMENT '对象类别：MEMBER / DEALER / AGENT / TABLE / GLOBAL',
  entity_id        VARCHAR(64)   NOT NULL COMMENT '对象标识：会员号 / 荷官工号 / lv3 代理线 / 桌号',

  /* ── 做了什么 ─────────────────────────────────────────────────────────── */
  action_type      VARCHAR(32)   NOT NULL COMMENT '动作类别，见下方值域约定',
  action_param     VARCHAR(256)           COMMENT '动作参数（如限红档位、退水下调 δ*、封盘提前秒数）',
  action_layer     VARCHAR(16)   NOT NULL COMMENT '处置层级：PRODUCT（产品参数）/ SETTLE（结算）/ ACCOUNT（账户）',
  is_reversible    TINYINT       NOT NULL COMMENT '可否回滚：1 可 / 0 不可。★ 不可回滚者须双人复核',

  /* ── 为什么（★ 因果与反作弊之根，缺此则账废） ──────────────────────────── */
  trigger_source   VARCHAR(32)   NOT NULL COMMENT '触发来源：GATE_T2 / GATE_R01 / GATE_R02 / GATE_R03 / MANUAL / COMPLAINT',
  trigger_gate     VARCHAR(32)            COMMENT '触发之闸：六领域闸之一（PROFIT/BETTING/ANOMALY/NETWORK/LIFECYCLE/FINANCIAL）',
  trigger_score    DECIMAL(18,6)          COMMENT '触发时之维度取值或综合分',
  trigger_thr      DECIMAL(18,6)          COMMENT '触发时之阈值（★ 一律记当期现算值，不记写死数）',
  reason_text      VARCHAR(1024) NOT NULL COMMENT '判定理由原文——★ 不得留空，留空即该笔作废',

  /* ── 实验设计（★ Gate 6 / Gate 7 之唯一凭据） ─────────────────────────── */
  arm              VARCHAR(16)   NOT NULL COMMENT '实验臂：TREATMENT / CONTROL / SHADOW。★ 无 CONTROL 则永无因果证据',
  assign_method    VARCHAR(32)   NOT NULL COMMENT '分配方式：RANDOM / PSM / RULE / NONE',
  assign_seed      VARCHAR(64)            COMMENT '随机种子或匹配批次号，供复现',
  cohort_id        VARCHAR(64)            COMMENT '实验批次号，同一次试运行共用',

  /* ── 复核 ─────────────────────────────────────────────────────────────── */
  review_required  TINYINT       NOT NULL COMMENT '是否须人工复核：1 是 / 0 否。★ 涉个体处置一律为 1',
  reviewed_by      VARCHAR(64)            COMMENT '复核人工号；高价值客群须二人，第二人记于 reviewed_by2',
  reviewed_by2     VARCHAR(64)            COMMENT '第二复核人工号',
  review_result    VARCHAR(16)            COMMENT '复核结论：APPROVE / REJECT / MODIFY',

  /* ── 成本（★ ΔNEV 之四项扣减，缺此则只能算 ΔGGR） ─────────────────────── */
  cost_review      DECIMAL(18,4)          COMMENT '复核成本：复核工时 × 工时单价',
  cost_treatment   DECIMAL(18,4)          COMMENT '处置成本：执行该动作之直接开销',
  cost_tech        DECIMAL(18,4)          COMMENT '技术成本：算力、系统改动之摊销',
  cost_operation   DECIMAL(18,4)          COMMENT '运营成本：沟通、安抚、客服之开销',

  /* ── 留痕 ─────────────────────────────────────────────────────────────── */
  changed_reason   VARCHAR(512)           COMMENT '★ 若本笔为对既有处置之变更，须记变更动机——只记改了什么而不记为何改，追溯只能还原动作不能还原意图',
  created_at       DATETIME      NOT NULL COMMENT '入账时刻',
  PRIMARY KEY (tl_id)
) COMMENT = 'a168 处置账：一行一次风控动作。CPOS 第七层，其后五层皆读此表';

/* ── action_type 值域约定（与本方案之处置纪律逐条对应）────────────────────
     PRODUCT 层（可回滚、可 A/B、对全体生效——本方案之首选）：
       LATE_SHOE_LIMIT   靴末段限红
       EARLY_CLOSE       提前封盘
       TABLE_LIMIT_TIER  桌限分层
       SIDE_BET_LIMIT    边注限额
     SETTLE 层（涉金钱，须二人复核一致）：
       REBATE_DOWN       退水档位下调 δ*
       REBATE_UP         退水上浮 γ*（★ 须先过净贡献门槛，否则等于替亏损加码）
       SETTLE_FREEZE     结算冻结复核
       COMMISSION_AUDIT  代理佣金审计
     ACCOUNT 层（不可回滚，本方案列为最后手段，永不自动化）：
       WATCH             入观察池（★ 此项不构成处置，但须记账以便统计观察池规模）
       ACCOUNT_LIMIT     账户限额
       ACCOUNT_SUSPEND   账户停用
   ★ 纪律：action_layer = 'ACCOUNT' 且 is_reversible = 0 者，
     review_required 必为 1 且 reviewed_by、reviewed_by2 皆不得为空。 */


/* ───────────────────────────────────────────────────────────────────────────
   二 · 结果账 outcome_ledger —— 记「做了之后怎么样」
   ---------------------------------------------------------------------------
   一行 = 一次处置 × 一个观察窗 × 一项结果指标。
   ★ 前后窗一律以处置账之 executed_at 为零点对齐；未执行者不产出结果行。
   ★ 观察窗须事前登记，不得事后挑窗——事后挑窗即是选择性报告。
   ─────────────────────────────────────────────────────────────────────────── */
CREATE TABLE IF NOT EXISTS a168_outcome_ledger (
  ol_id            VARCHAR(64)   NOT NULL COMMENT '结果流水号',
  tl_id            VARCHAR(64)   NOT NULL COMMENT '对应之处置流水号（外键指向处置账）',
  entity_type      VARCHAR(16)   NOT NULL COMMENT '对象类别，与处置账一致',
  entity_id        VARCHAR(64)   NOT NULL COMMENT '对象标识，与处置账一致',
  arm              VARCHAR(16)   NOT NULL COMMENT '实验臂，自处置账带下，供分组比较',

  /* ── 观察窗（★ 事前登记，不得事后挑） ────────────────────────────────── */
  window_tag       VARCHAR(16)   NOT NULL COMMENT '窗标签：PRE_28D / POST_7D / POST_28D / POST_90D',
  window_start     DATE          NOT NULL COMMENT '窗起（含）',
  window_end       DATE          NOT NULL COMMENT '窗止（不含）',
  n_active_days    INT                    COMMENT '窗内活跃日数——样本量之凭据，缺此则显著性是虚的',

  /* ── 结果指标（一律与本方案既有口径同源，不另立算法） ─────────────────── */
  validbet         DECIMAL(20,4)          COMMENT '有效投注（洗码量）——ROI 之分母，非原始投注额',
  ggr              DECIMAL(20,4)          COMMENT '毛博彩收入（平台视角）',
  rebate           DECIMAL(20,4)          COMMENT '返水支出',
  commission       DECIMAL(20,4)          COMMENT '占成支出',
  ngr              DECIMAL(20,4)          COMMENT '净博彩收入（★ 本平台只能算到三扣，对外须声明）',
  n_rounds         BIGINT                 COMMENT '窗内局数',
  is_retained      TINYINT                COMMENT '窗内是否仍有下注：1 留存 / 0 流失',
  days_to_return   INT                    COMMENT '距下次下注之天数；未回返者留空（★ 留空 ≠ 0，见五类零之别）',
  n_complaint      INT                    COMMENT '窗内客诉件数',
  n_appeal         INT                    COMMENT '窗内申诉件数',
  appeal_overturn  INT                    COMMENT '申诉推翻件数——★ 误伤率之金标准，风控专员评分之缺口正在此',

  /* ── 数据品质守卫 ─────────────────────────────────────────────────────── */
  is_censored      TINYINT       NOT NULL COMMENT '是否右删失（窗未走完即结算）：1 是 / 0 否。★ 删失当完整用即高估留存',
  src_snapshot_at  DATETIME      NOT NULL COMMENT '结果计算时之数据快照时刻，供复算对账',
  created_at       DATETIME      NOT NULL COMMENT '入账时刻',
  PRIMARY KEY (ol_id)
) COMMENT = 'a168 结果账：一行一次处置之一个观察窗。CPOS 第八层';


/* ───────────────────────────────────────────────────────────────────────────
   三 · 建账手续（八条，缺一即账不成立）
   ───────────────────────────────────────────────────────────────────────────
   ① 零点唯一：因果分析之事件零点一律取 executed_at，不取 decided_at。
      决定了而未执行者，其对象须留在对照侧，不得算作已处置——
      否则即是把「打算做的事」当成「做过的事」。

   ② 对照必留：凡试运行，一律留一批不处置者为 CONTROL。
      arm = 'NONE' 或全表皆 TREATMENT 者，本方案一律判为无因果证据。
      ★ 留对照的成本，是本方案能否说出「赚了多少」的唯一代价。

   ③ 分配须记：assign_method 与 assign_seed 缺一，随机性即不可复现，
      不可复现之随机等同于不随机。

   ④ 理由不空：reason_text 留空者，该笔作废。
      此非形式主义——理由是日后判断「当时凭什么」的唯一凭据。

   ⑤ 窗先登记：观察窗于试运行开始前即登记，跑完再挑窗即是选择性报告。

   ⑥ 成本同记：四项成本与处置同笔记录。事后估成本，必然低估——
      因为最容易忘的正是复核工时与安抚客人的时间。

   ⑦ 变更留意图：changed_reason 记的是「为何改」，非「改了什么」。
      只记动作不记意图，追溯只能还原动作、不能还原判断。

   ⑧ 五类零之别贯穿全链：真零 / 缺失 / 不适用 / 未采集 / 证据不足，
      五者语义各异，一律不得混为 0。导出至看板时尤须守住——
      多数 BI 工具默认把缺失画成 0，一导即把纪律推翻。


   四 · 最小可行起步（明日即可开始，不必等系统）
   ───────────────────────────────────────────────────────────────────────────
   先只填十二个必填字段，其余留空亦可成账：
     tl_id · decided_by · decided_at · executed_at · entity_type · entity_id ·
     action_type · action_layer · reason_text · arm · assign_method · created_at

   载体不拘：共享表单、Excel、工单系统皆可，每日导一次 CSV 入库即可。
   ★ 账早一天开始长，因果证据就早一天可能取得。
     等一套系统建成再开始记，等于把 CPOS 后六层再推后一个季度。


   五 · 建成之后解锁什么（逐条对应，非泛言）
   ───────────────────────────────────────────────────────────────────────────
     · P&L Gate 之 Gate 5 处置可执行      → 有 executed_at 即可判过
     · P&L Gate 之 Gate 6 对照组存在      → 有 arm = 'CONTROL' 即可判过
     · P&L Gate 之 Gate 7 随机化/准实验   → 有 assign_method = 'RANDOM' 即可判过
     · P&L Gate 之 Gate 8 增量 NGR        → 两账相接即可算，且带 95% 置信区间
     · P&L Gate 之 Gate 9 成本扣除        → 四项成本齐备即为完整 ΔNEV
     · 风控专员之「命中率」「误标率」      → 由处置账对回结果账即得，
                                             该实体自此脱离「只有六人、四年前数据」之窘境
     · 反作弊层之「标注命中率」            → 同上，专员多标乱标即刻现形
     · 漂移之「标签漂移」监看              → 有持续新增之判定，方有新标签可比
     · 可信度木桶之三块零板                → 结果完整 / 因果验证 / 增量 NGR 三维自零起算

   ★ 一句话：这两本账不产生任何新模型，
     但没有它，前面二十件军械算得再干净，都只能停在「观察到改善」。
   ═══════════════════════════════════════════════════════════════════════════ */
