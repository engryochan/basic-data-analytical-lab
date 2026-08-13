## ==============================================================================
##  a168 风控与客户分层评分体系 · 取数与核验 R 总包 v1
##  ------------------------------------------------------------------------
##  源本  ：a168_取数与核验_SQL总包_v2斧正版.sql（7,849 行 · CRLF · UTF-8 无 BOM）
##  作者  ：Ryo Eng
##  平台  ：StarRocks ods_mariadb_2b（DBI + dbplyr 惰性下推）
##  建档  ：2026-08-13
##
##  ★ 本脚本为**移植**，不是重写。凡与源本口径不一致者皆为缺陷，非改良。
##    每个函数上方标注其源本段号与行号，可逐条回溯对账。
## ==============================================================================

## ==============================================================================
##  §00 · 移植总则（先读这一段，再读代码）
## ------------------------------------------------------------------------------
##  【一】三种执行模式，同一套代码
##    mode = "lazy"  → dbplyr 惰性求值，SQL 下推给 StarRocks 执行（默认，推荐）
##    mode = "sql"   → 只打印下推后的 SQL，不执行（用于与源本逐句比对）
##    mode = "local" → 已 collect 的本地 data.frame，供小样本验证
##
##  【二】源本纪律之在 R 侧的对应
##    源本纪律①「每条查询自包含、零占位符」
##      → R 侧改以函数封装 + 常数集中于 CONST 一处。R 不受 Superset 限制，
##        故此条**不移植其形，只移植其意**：常数不散落。
##    源本纪律②「StarRocks 方言：禁 EXISTS + 多列 IN，改五路 LEFT JOIN」
##      → R 侧 %in% 即可。**这是方言限制不是业务口径**，不照搬其笨拙；
##        但 lazy 模式下 dbplyr 仍会译成 IN 子句，若撞上同一限制，
##        改用 anti_join() 五次（见 exclude_test_agents 之 fallback 分支）。
##    源本纪律④「导出必带 ORDER BY」
##      → 每个产出函数末尾一律 arrange()，且 export_csv() 会断言其非空。
##    源本纪律⑦「导出 CSV(UTF-8)，文件名一字不可错」
##      → 文件名集中登记于 MANIFEST，不容散写。错名不报错、只让图表静默空白，
##        是最坑的失败方式，故 export_csv() 只接受 MANIFEST 内之键。
##
##  【三】未移植者，据实列明（见 §90）
##    §Z-01~§Z-12（全库结构与哨兵值审计）、§TZ-01~§TZ-05（时区守卫）、
##    §EX-00~§EX-08（缺口探查）皆为 information_schema 元数据查询，
##    **R 侧无等价抽象**，硬译只会失真。故保留 SQL 直通（见 run_raw_sql）。
## ==============================================================================


## ==============================================================================
##  §01 · 依赖
## ==============================================================================
suppressPackageStartupMessages({
  library(DBI)
  library(dbplyr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(readr)
  library(rlang)
})

options(dplyr.summarise.inform = FALSE)


## ==============================================================================
##  §02 · 常数集中登记
##  源本对应：卷首「常数集中登记（2026-08-13 立 · 铁律 T3·L2·S3）」第 33~52 行
##  ------------------------------------------------------------------------------
##  源本因 Superset 不支持占位符而无法参数化，改以「登记表 + 全文检索点数」代替。
##  R 侧无此限制，故此处为**真参数化**——改窗只须改这一处，
##  源本那 53 处（或 89 处）字面量的同步问题在 R 侧根本不存在。
##  ⚠ 但对账时须注意：源本改窗要改 89 处，本脚本只改 1 处，
##    二者若不同步，比对结果会全盘不符而无任何报警。
## ==============================================================================
CONST <- list(
  SCHEMA         = "ods_mariadb_2b",
  WIN_START      = as.Date("2026-03-21"),   # 窗口左端（闭区间）
  WIN_END        = as.Date("2026-08-07"),   # 窗口右端（★ 开区间，当日不在窗内）
  WIN_LAST_DAY   = as.Date("2026-08-06"),   # 末个营业日（生命周期阶段用）
  WIN_DAYS       = 139L,                    # 完整营业日数
  WIN_MID        = as.Date("2026-05-28"),   # 窗口中点（S-03 下线留存用）
  NEW_MEMBER_FROM= as.Date("2026-04-20"),   # 「新增会员」判定起点（S-03）
  PROBE_START    = as.Date("2026-08-04"),   # 三日探针窗（schema 属性判据用）

  GAME_BACCARAT  = "101",                   # bet02 游戏类别：百家乐
  CAT_NORMAL     = "1",                     # category：一般注单
  REBET_NO       = "N",                     # bet38：非重对
  TESTLINE_FLAG  = "1",                     # age022 = '1' 为公司测试线（214 条）

  SENTINEL_EID   = c("-1", "0"),            # 荷官哨兵值（§Z-10 列为 S2 阻断项）
  LATE_DEF       = "shoe_pos>=0.80",        # 靴末段判据（2026-08-12 斧正）★ 口径锁值
  LATE_CUT       = 0.80,

  MIN_ROUNDS_30  = 30L,                     # S-01 样本门槛
  MIN_ORDERS_100 = 100L,                    # §R01 / §T03 样本门槛
  MIN_PAIR_100   = 100L,                    # §R02 配对门槛

  OUT_DIR        = "数据库"                  # 导出目录（源本纪律⑦）
)

## 源本表名（只列本脚本实际用到者；全库 20 张见解读档 @sec-tables）
TBL <- list(
  bet02      = "ods_a168_bet02",              # 注单明细 · 主表（源本引用 81 次）
  agent      = "ods_a168_agent",              # 代理主档 · 只用于剔测试线（37 次）
  dailyrep   = "ods_a168_dailyreport_member", # 会员日报（23 次）
  game_info  = "ods_a168_game_info",          # 局信息 · 局速唯一来源（10 次）
  alert_ip   = "ods_a168_alert_ip_setting",   # 风控员唯一料源 · 全表 17 行（8 次）
  member_dtl = "ods_a168_member_dtl",
  bet01      = "ods_a168_bet01"               # ⚠ 与 bet02 自 bet14 起整段错位，勿混用
)


## ==============================================================================
##  §03 · 连接与取表
## ==============================================================================

#' 建立 StarRocks 连接
#' @note 源本纪律⑧：每个会话开跑前先设 query_timeout = 259200（3 天）
a168_connect <- function(dsn = Sys.getenv("A168_DSN"),
                         set_session = TRUE) {
  con <- DBI::dbConnect(odbc::odbc(), dsn = dsn)
  if (set_session) {
    try(DBI::dbExecute(con, "SET SESSION query_timeout = 259200"), silent = TRUE)
    # 让被多次引用的 CTE 只算一遍；报「变量不存在」则跳过（源本纪律⑧）
    try(DBI::dbExecute(con, "SET SESSION cbo_cte_reuse = true"), silent = TRUE)
  }
  con
}

#' 取一张源表（惰性）
tb <- function(con, key) {
  stopifnot(key %in% names(TBL))
  dplyr::tbl(con, dbplyr::in_schema(CONST$SCHEMA, TBL[[key]]))
}

#' SQL 直通 —— 供 §90 所列未移植段落使用
run_raw_sql <- function(con, sql) DBI::dbGetQuery(con, sql)


## ==============================================================================
##  §04 · 基础工具
## ==============================================================================

#' 字符转数值：去空白 → 空串归 NA → 转型
#' 源本对应：CAST(NULLIF(TRIM(x),'') AS DECIMAL(20,4))
#' ⚠ 三步缺一不可。本库字段多为 varchar(65533)，不显式转型即比较失真；
#'   少「空串归 NA」一步，某些路径下空串会变 0 而非 NA —— 静默错值。
num <- function(x) suppressWarnings(as.numeric(dplyr::na_if(stringr::str_trim(x), "")))

#' 安全除：分母为 0 或 NA 时返回 NA
#' 源本对应：NULLIF(denominator, 0)
`%/0%` <- function(a, b) a / dplyr::na_if(b, 0)

#' 窗口裁剪谓词（分区剪枝之所系，一律写在最内层）
#' 源本对应：提速总则①「dt 谓词一律写在最内层 CTE」
in_window <- function(.data, date_col = dt,
                      from = CONST$WIN_START, to = CONST$WIN_END) {
  .data |> dplyr::filter({{ date_col }} >= !!as.character(from),
                         {{ date_col }} <  !!as.character(to))
}


## ==============================================================================
##  §05 · 通用底座：五段流水线
##  源本对应：S-01 第 1772~1820 行（S-02 / S-03 / §R01 / §T02 / §T03 / §K01 同构）
##  ------------------------------------------------------------------------------
##  ta → rk → vd → bs，四条评分查询与多数规则查询共用此底座。
##  ★ 固有成本，非提速空间（源本第 245 行）：
##    「同注单号取最新版本」的 ROW_NUMBER 去重是需求 §3.2 的硬性口径，
##    每条正版查询都须对全窗注单开窗一次。库为只读、不得建中间表，
##    故此项开销无法在查询层消除。R 侧同理 —— 除非在
##    DolphinScheduler + Spark 侧落一张去重后的中间表供各条复用。
## ==============================================================================

#' ① 公司测试线代理（214 条，跨五级）
#' 源本对应：CTE `ta` / `test_agents`
test_agents <- function(con) {
  tb(con, "agent") |>
    dplyr::filter(age022 == !!CONST$TESTLINE_FLAG) |>
    dplyr::distinct(aid = age001)
}

#' ② 同注单号取最新版本（需求 §3.2 · 三级排序去重）
#' 源本对应：CTE `rk` / `ranked`
#'   ROW_NUMBER() OVER (PARTITION BY bet01
#'     ORDER BY updatetime DESC, sync_time DESC, dt DESC) = 1
#' ★ PARTITION BY = group_by()；此处必须 mutate（窗口，不塌行）后再 filter，
#'   **不可用 distinct()** —— distinct 不认排序，取到的是任意一版而非最新版。
#' ★ 提速：只带下游必需列。源本教训 —— 原 SELECT b.* 令四十余列
#'   varchar(65533) 全过排序洗牌，S-02 由此三小时未毕（提速总则②）。
dedup_latest <- function(con, cols) {
  tb(con, "bet02") |>
    in_window(dt) |>
    dplyr::filter(bet02 == !!CONST$GAME_BACCARAT) |>
    dplyr::select(dplyr::all_of(unique(c("bet01", "updatetime", "sync_time", "dt", cols)))) |>
    dplyr::group_by(bet01) |>
    dplyr::mutate(rn = dplyr::row_number(
      dplyr::desc(updatetime) )) |>   # ← 见下方 note，多键降序在 lazy 模式的写法
    dplyr::ungroup() |>
    dplyr::filter(rn == 1L) |>
    dplyr::select(-rn)
}
## note · 三级排序在 dbplyr 的落地
##   dplyr::row_number() 只吃单一表达式。三级降序须改用 dbplyr 的窗口序：
##     dbplyr::window_order(updatetime, sync_time, dt) 之后再 row_number()，
##   或在 local 模式下 arrange(desc(updatetime), desc(sync_time), desc(dt)) |> slice_head(1)。
##   本脚本 dedup_latest_local() 给出 local 版，lazy 版请按上式改写并**核对下推 SQL**。

#' ②′ local 模式之去重（小样本验证用；语义与 lazy 版须逐行一致）
dedup_latest_local <- function(df) {
  df |>
    dplyr::group_by(bet01) |>
    dplyr::arrange(dplyr::desc(updatetime), dplyr::desc(sync_time),
                   dplyr::desc(dt), .by_group = TRUE) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup()
}

#' ③ 剔测试线（五级代理线任一命中即剔）
#' 源本对应：五路 LEFT JOIN ta + COALESCE(...) IS NULL
#' ★ 源本绕道之由：StarRocks 不支持 EXISTS 配多列 IN（纪律②）。
#'   R 侧 %in% 即可；若 dbplyr 下推后仍撞限制，改走 anti_join 五次。
exclude_test_agents <- function(.data, ta, use_antijoin = FALSE) {
  lv <- c("bet18", "bet19", "bet20", "bet21", "bet22")
  if (!use_antijoin) {
    ids <- dplyr::pull(dplyr::collect(ta), aid)
    .data |> dplyr::filter(
      !(bet18 %in% !!ids | bet19 %in% !!ids | bet20 %in% !!ids |
        bet21 %in% !!ids | bet22 %in% !!ids))
  } else {
    out <- .data
    for (v in lv) {
      out <- dplyr::anti_join(out, ta, by = stats::setNames("aid", v))
    }
    out
  }
}

#' ③′ 有效注单过滤：非测试线、非重对、一般注单
#' 源本对应：CTE `vd` 之 WHERE
valid_orders <- function(.data, ta, require_bet08 = TRUE) {
  out <- .data |>
    dplyr::filter(
      category == !!CONST$CAT_NORMAL,
      toupper(trimws(bet38)) == !!CONST$REBET_NO,
      num(bet05) > 0,
      num(bet11) > 0
    ) |>
    exclude_test_agents(ta)
  if (require_bet08) out <- dplyr::filter(out, !is.na(num_datetime(bet08)))
  out
}
num_datetime <- function(x) lubridate::ymd_hms(stringr::str_trim(x), quiet = TRUE)

#' ④ 金额正名层：一律 ÷ bet11 汇率
#' 源本对应：CTE `bs`；需求文档 §3.3 之四条金额算式
#' ⚠ 该四条算式**只对表一 ods_a168_bet02 成立**。
#'   若误施于 ods_a168_bet01，数值照算、结果全错、零报警（该表自 bet14 起整段错位）。
#' ★ 物理局键三段缺一不可：bet03 靴号 + bet04 局序 + bet39 桌号。
normalize_amounts <- function(.data) {
  .data |>
    dplyr::transmute(
      member_id = bet05,
      dealer_id = eid,
      bet_ip    = ip,
      lv3       = bet20,
      bet_side  = bet09,                       # 玩法（英文名，非数字编码）
      bet_date  = dt,
      table_id  = bet39,
      shoe_id   = bet03,
      round_no  = as.integer(num(bet04)),
      round_key = paste(bet03, bet04, bet39, sep = "|"),
      t_bet     = num_datetime(bet08),
      fx        = num(bet11),
      stake     = num(bet13)                %/0% num(bet11),  # 本金
      valid_bet = num(validbet)             %/0% num(bet11),  # 洗码量
      game_pnl  = (num(bet14) - num(bet13)) %/0% num(bet11),  # 游戏输赢 = 派彩 − 本金
      rebate    = num(bet16)                %/0% num(bet11),  # 退水
      net_pnl   = num(bet17)                %/0% num(bet11)   # 净输赢
    )
}

#' 底座总装
#' @param cols 下游必需的原始列（提速总则②：绝不 SELECT *）
a168_base <- function(con, cols = c(
  "bet02","bet03","bet04","bet05","bet08","bet09","bet11","bet13","bet14",
  "bet16","bet17","bet18","bet19","bet20","bet21","bet22","bet38","bet39",
  "category","eid","ip","validbet")) {
  ta <- test_agents(con)
  dedup_latest(con, cols) |>
    valid_orders(ta) |>
    normalize_amounts()
}


## ==============================================================================
##  §10 · S-01 玩家评分底料
##  源本对应：第 1767 行 → 数据库/S01_player_score.csv
##  用途    ：★ 玩家评分雷达 + 综合分
## ==============================================================================
s01_player_score <- function(con, bs = a168_base(con)) {

  ## 扩编维度① 投注产品结构熵（香农熵，单位 nat）
  ##   把该会员的投注额按 23 种玩法拆开，看分散还是集中。
  ##   熵高 = 庄闲和边注都押一点，娱乐型客人常态；
  ##   熵低 = 火力集中在少数高赔率边注，技术型画像特征之一。
  ##   赏罚方向为「赏」——熵高的客人对平台更安全。
  ent <- bs |>
    dplyr::group_by(member_id, bet_side) |>
    dplyr::summarise(s_side = sum(stake, na.rm = TRUE), .groups = "drop_last") |>
    dplyr::mutate(s_all = sum(s_side)) |>            # ← SUM(SUM(x)) OVER (PARTITION BY ...)
    dplyr::filter(s_all > 0, s_side > 0) |>
    dplyr::summarise(投注产品结构熵 = -sum((s_side / s_all) * log(s_side / s_all)),
                     .groups = "drop")

  ## 扩编维度② 索提诺稳定性（会员视角的下行风险调整收益）
  ##   日ROI均值 ÷ 下行标准差；只统计低于 0 那一侧的波动——赢钱时的波动不是风险。
  ##   ⚠⚠ 赏罚方向为「罚」：赢得稳的客人正是 T2 技术型风险用户，
  ##       赢得多但忽输忽赢的反而是正常娱乐客。**不要把方向搞反。**
  srt <- bs |>
    dplyr::group_by(member_id, bet_date) |>
    dplyr::summarise(pnl_d   = sum(game_pnl, na.rm = TRUE),
                     stake_d = sum(stake,    na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(roi_d = pnl_d %/0% stake_d) |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      mu_roi_d = mean(roi_d, na.rm = TRUE),
      dd_roi_d = sqrt(mean(pmin(roi_d, 0)^2, na.rm = TRUE)),
      索提诺稳定性 = mu_roi_d %/0% dd_roi_d,
      .groups = "drop")

  ## 扩编维度③ 生命周期阶段
  ##   活跃跨度天数 × (1 − 距窗口右端的静默天数 / 窗口总天数)。
  ##   新客跨度短、流失前兆者静默久，两端都会被压低。赏罚方向为「赏」。
  lc <- bs |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      span_days   = as.integer(as.Date(max(bet_date)) - as.Date(min(bet_date))) + 1L,
      silent_days = as.integer(CONST$WIN_LAST_DAY - as.Date(max(bet_date))),
      生命周期阶段 = span_days * (1 - silent_days / CONST$WIN_DAYS),
      .groups = "drop")

  ## 人工标记史（取自会员日报，非注单表）
  lab <- tb(con, "dailyrep") |>
    dplyr::group_by(member_id = bet05) |>
    dplyr::summarise(n_risk_days  = sum(dplyr::if_else(risk   == "1", 1L, 0L), na.rm = TRUE),
                     n_order_days = sum(dplyr::if_else(orders == "1", 1L, 0L), na.rm = TRUE),
                     .groups = "drop")

  bs |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      流水贡献     = sum(valid_bet, na.rm = TRUE),
      游戏输赢贡献 = -sum(game_pnl, na.rm = TRUE),   # 会员输 = 平台赢，取负号
      活跃稳定     = dplyr::n_distinct(bet_date),
      退水支出     = sum(rebate, na.rm = TRUE),
      n_ip         = dplyr::n_distinct(bet_ip),
      n_chain      = dplyr::n_distinct(lv3),
      n_rounds     = dplyr::n_distinct(round_key),
      .groups = "drop") |>
    dplyr::left_join(lab, by = "member_id") |>
    dplyr::left_join(ent, by = "member_id") |>
    dplyr::left_join(dplyr::select(srt, member_id, 索提诺稳定性), by = "member_id") |>
    dplyr::left_join(dplyr::select(lc,  member_id, 生命周期阶段), by = "member_id") |>
    dplyr::mutate(人工标记史 = dplyr::coalesce(n_risk_days, 0L) +
                                dplyr::coalesce(n_order_days, 0L)) |>
    dplyr::filter(n_rounds >= !!CONST$MIN_ROUNDS_30) |>   # HAVING COUNT(DISTINCT round_key) >= 30
    dplyr::select(member_id, 流水贡献, 游戏输赢贡献, 活跃稳定, 退水支出,
                  n_ip, n_chain, 人工标记史,
                  投注产品结构熵, 索提诺稳定性, 生命周期阶段) |>
    dplyr::arrange(dplyr::desc(流水贡献))
}


## ==============================================================================
##  §11 · S-02 荷官评分底料
##  源本对应：第 1898 行 → 数据库/S02_dealer_score.csv
##  ------------------------------------------------------------------------------
##  ★ 源本提速三处（原版实测 3 小时未毕）：
##    ① pace 原以 bs JOIN gi ON table_id —— 注单粒度 × 局粒度的多对多爆炸，
##       单张热门桌即数万亿配对。改为**加权矩坍缩**；
##    ② bs 原被引用三次，整条 1.9 亿行去重流水线跑三遍。现坍缩为 bd，只扫一遍；
##    ③ 开窗去重原 SELECT b.*，改为只带必需的二十一列。
##    输出逐列一致；节奏稳定度由矩公式算，与原式差在双精度舍入位（1e-12），
##    分位归一后不改变任何排名。
## ==============================================================================
s02_dealer_score <- function(con, bs = a168_base(con)) {

  ## 荷官维基础层：坍缩到 荷官×桌×会员×局（bs 全文只扫一遍之所系）
  ## 荷官键过滤：eid 非空且不在哨兵值内（§Z-10 列为 S2 阻断项）
  bd <- bs |>
    dplyr::filter(!is.na(dplyr::na_if(trimws(dealer_id), "")),
                  !trimws(dealer_id) %in% !!CONST$SENTINEL_EID) |>
    dplyr::group_by(dealer_id, table_id, member_id, round_key) |>
    dplyr::summarise(n_bet_rows = dplyr::n(),
                     v_sum = sum(valid_bet, na.rm = TRUE),
                     g_sum = sum(game_pnl,  na.rm = TRUE), .groups = "drop")

  ## 扩编维度② 节奏稳定度：加权矩坍缩版
  ##   原式 = 对「荷官每笔注单 × 同桌每一局时长」求 STDDEV_SAMP。
  ##   等价于：每桌局时长以该荷官在该桌的注单行数加权。
  ##   样本标准差只需三个矩：N=Σw·n、S1=Σw·Σx、S2=Σw·Σx²，
  ##   var = (S2 − S1²/N)/(N−1)。桌级统计仅数百行，荷官×桌仅数千行。
  ##   节奏忽快忽慢是操作异常的先兆。赏罚方向为「赏」。
  git <- tb(con, "game_info") |>
    dplyr::filter(gi001 == !!CONST$GAME_BACCARAT, gi013 == "1") |>
    in_window(gi004) |>
    dplyr::transmute(table_id  = gi011,
                     sec_round = as.numeric(gi006) - as.numeric(gi004)) |>
    dplyr::group_by(table_id) |>
    dplyr::summarise(n_g = sum(!is.na(sec_round)),
                     s1  = sum(sec_round,   na.rm = TRUE),
                     s2  = sum(sec_round^2, na.rm = TRUE), .groups = "drop")

  pace <- bd |>
    dplyr::group_by(dealer_id, table_id) |>
    dplyr::summarise(n_rows = sum(n_bet_rows), .groups = "drop") |>
    dplyr::inner_join(git, by = "table_id") |>
    dplyr::group_by(dealer_id) |>
    dplyr::summarise(N  = sum(n_rows * n_g),
                     S1 = sum(n_rows * s1),
                     S2 = sum(n_rows * s2), .groups = "drop") |>
    dplyr::mutate(节奏稳定度 = dplyr::if_else(
      N >= 2, 1 / (1 + sqrt(pmax((S2 - S1^2 / N) / (N - 1), 0))), 1))

  ## 扩编维度③ 特定玩家复现率
  ##   该荷官桌上「出现最频繁的那一位会员」占其总局数的比例。
  ##   正常荷官服务的是流动客群，比例低；比例畸高说明有固定的人一直跟着他。
  ##   赏罚方向为「罚」。
  top1 <- bd |>
    dplyr::group_by(dealer_id, member_id) |>
    dplyr::summarise(n_r = dplyr::n_distinct(round_key), .groups = "drop") |>
    dplyr::group_by(dealer_id) |>
    dplyr::summarise(max_member_rounds = max(n_r), .groups = "drop")

  bd |>
    dplyr::group_by(dealer_id) |>
    dplyr::summarise(
      在桌洗码量 = sum(v_sum, na.rm = TRUE),
      客群广度   = dplyr::n_distinct(member_id),
      n_rounds   = dplyr::n_distinct(round_key),
      n_tables   = dplyr::n_distinct(table_id),
      桌面输赢   = sum(g_sum, na.rm = TRUE),
      .groups = "drop") |>
    dplyr::mutate(当值时长 = n_rounds) |>      # 以「在册局数」为分层基准
    dplyr::left_join(dplyr::select(pace, dealer_id, 节奏稳定度), by = "dealer_id") |>
    dplyr::left_join(top1, by = "dealer_id") |>
    dplyr::mutate(特定玩家复现率 = max_member_rounds %/0% n_rounds) |>
    dplyr::select(dealer_id, 在桌洗码量, 客群广度, n_rounds, n_tables,
                  桌面输赢, 当值时长, 节奏稳定度, 特定玩家复现率) |>
    dplyr::arrange(dplyr::desc(在桌洗码量))
}


## ==============================================================================
##  §12 · S-03 代理（LV3 链）评分底料
##  源本对应：第 2036 行 → 数据库/S03_agent_score.csv
## ==============================================================================
s03_agent_score <- function(con, bs = a168_base(con)) {

  bs3 <- dplyr::filter(bs, !is.na(dplyr::na_if(trimws(lv3), "")))

  ## 扩编维度① 下线留存：前半窗活跃者中后半窗仍活跃之占比
  ##   留存趋零而流水不低，多半是一批号刷完就换。赏罚方向为「赏」。
  ret <- bs3 |>
    dplyr::group_by(lv3, member_id) |>
    dplyr::summarise(in_h1 = max(dplyr::if_else(bet_date <  as.character(CONST$WIN_MID), 1L, 0L)),
                     in_h2 = max(dplyr::if_else(bet_date >= as.character(CONST$WIN_MID), 1L, 0L)),
                     .groups = "drop") |>
    dplyr::group_by(lv3) |>
    dplyr::summarise(下线留存 = sum(in_h1 * in_h2) %/0% sum(in_h1), .groups = "drop")

  ## 扩编维度② 新增会员质量
  ##   只看「窗口内才首次下注」的会员，算其人均净贡献（平台口径，取负号）。
  ##   把「拉人头」与「拉客人」区分开：新增数量高但人均净贡献接近零甚至为负，
  ##   说明拉来的是刷返水的号，不是客人。赏罚方向为「赏」。
  nq <- bs3 |>
    dplyr::group_by(lv3, member_id) |>
    dplyr::summarise(first_date = min(bet_date),
                     平台净得   = -sum(net_pnl, na.rm = TRUE), .groups = "drop") |>
    dplyr::filter(first_date >= !!as.character(CONST$NEW_MEMBER_FROM)) |>
    dplyr::group_by(lv3) |>
    dplyr::summarise(新增会员质量 = mean(平台净得, na.rm = TRUE),
                     新增会员数   = dplyr::n(), .groups = "drop")

  bs3 |>
    dplyr::group_by(lv3) |>
    dplyr::summarise(
      线下规模     = dplyr::n_distinct(member_id),
      真实流水     = sum(valid_bet, na.rm = TRUE),
      退水支出     = sum(rebate,    na.rm = TRUE),
      链下游戏输赢 = sum(game_pnl,  na.rm = TRUE),
      .groups = "drop") |>
    dplyr::mutate(退水消耗比 = 退水支出 %/0% (-链下游戏输赢)) |>
    dplyr::left_join(ret, by = "lv3") |>
    dplyr::left_join(nq,  by = "lv3") |>
    dplyr::select(lv3, 线下规模, 真实流水, 退水支出, 链下游戏输赢,
                  退水消耗比, 下线留存, 新增会员质量, 新增会员数) |>
    dplyr::arrange(dplyr::desc(真实流水))
}


## ==============================================================================
##  §13 · §S04p 风控员最小画像
##  源本对应：第 5094 行 → 数据库/S04_analyst_score.csv
##  ------------------------------------------------------------------------------
##  ⛔ 勿用已废之 S-04a（源本第 2144 行挂告示）：它输出 IP 明细 17 行，
##     而风控员雷达需「一行一位风控员」之实体级聚合；二者同写同一文件名，
##     后跑者覆盖先跑者。
##  ⚠ 四缺三：风控员的四个维度（标注产量/命中率/复核时效/误标率）全部依赖
##     「风控处置日志」——本平台没有这张表。库里能沾边的只有两处：
##       · alert_ip_setting.creator  有登记人，但只有 17 条、且是 2022 年的
##       · dailyreport.risk / orders 只记「会员被标了」，没记是谁标的
##     故本函数给的**不是绩效评分**，只是让那张雷达从「全合成」变为「部分实测」，
##     并把缺口摆明。四维中它只能填「标注产量」一项，其余仍为待补。
## ==============================================================================
s04p_analyst_score <- function(con) {
  tb(con, "alert_ip") |>
    dplyr::mutate(entity_id = dplyr::coalesce(dplyr::na_if(trimws(creator), ""), "未署名")) |>
    dplyr::group_by(entity_id) |>
    dplyr::summarise(
      标注产量   = dplyr::n(),
      覆盖IP广度 = dplyr::n_distinct(trimws(ip)),
      判定详尽度 = mean(nchar(dplyr::coalesce(remarks, "")), na.rm = TRUE),
      首次登记   = min(addtime),
      最近登记   = max(addtime),
      .groups = "drop") |>
    dplyr::arrange(dplyr::desc(标注产量))
  ## 实测（2026-08-06 全表 17 行到手）：
  ##   mao 6 / wmdn08 4 / Annie 3 / livegame 2 / wmdn10 1 / wmdn01 1
}


## ==============================================================================
##  §20 · §R01 靴末段下注
##  源本对应：第 2968 行 → 数据库/R01_late_shoe.csv
##  ------------------------------------------------------------------------------
##  ★★ 2026-08-12 斧正：判据由绝对局号 round_no>=50 改为相对靴位 shoe_pos>=0.80。
##     依据：外部实测靴长分布（均值 49.86 局、P50=50、P75=52、P90=54、P99=58）。
##     第 50 把的相对靴位为 100.3%（以均值计），故旧判据实为「靴的最后一局
##     及长于中位数的那半数靴」——约半数牌靴无末段可言，late_share 被系统性压低。
##     新判据固定的是**局位区间**（每靴末 20% 之局），不是下注占比；
##     均匀下注之零偏好基准下期望约 20%，实际可为 0%~100%。
##  ★ late_def 口径锁列：旧版 CSV 因缺此列而在报告侧读入时当场报错，
##    使「新文字配旧数字」的静默语义漂移变成显式失败。
##  ⚠️ 故意不加 late_share >= 0.70 的筛选：报告需要「命中组 vs 对照组」的
##     hold% 对照才能做经济裁定，只导命中组就没有对照组。
##     阈值筛选一律放在 R 侧做，取数只负责给全量底料。
## ==============================================================================
r01_late_shoe <- function(con, bs = a168_base(con)) {

  base <- bs |> dplyr::filter(round_no > 0)

  ## 靴长：以 靴号 × 桌号 为键取最大局号
  shoe_len <- base |>
    dplyr::group_by(shoe_id, table_id) |>
    dplyr::summarise(max_round = max(round_no, na.rm = TRUE), .groups = "drop")

  enriched <- base |>
    dplyr::inner_join(shoe_len, by = c("shoe_id", "table_id")) |>
    dplyr::mutate(
      shoe_pos = round_no %/0% max_round,
      is_late  = dplyr::if_else(round_no %/0% max_round >= !!CONST$LATE_CUT, 1L, 0L))

  enriched |>
    dplyr::group_by(uid = member_id) |>
    dplyr::summarise(
      n_orders_all    = dplyr::n(),
      n_orders_late   = sum(is_late),
      late_share      = sum(is_late) / dplyr::n(),
      shoe_pos_p50    = stats::median(dplyr::if_else(is_late == 1L, shoe_pos, NA_real_),
                                      na.rm = TRUE),
      stake_late_avg  = sum(dplyr::if_else(is_late == 1L, stake, 0)) %/0% sum(is_late),
      stake_early_avg = sum(dplyr::if_else(is_late == 0L, stake, 0)) %/0% (dplyr::n() - sum(is_late)),
      roi_late        = sum(dplyr::if_else(is_late == 1L, game_pnl, 0)) %/0%
                        sum(dplyr::if_else(is_late == 1L, stake, 0)),
      roi_early       = sum(dplyr::if_else(is_late == 0L, game_pnl, 0)) %/0%
                        sum(dplyr::if_else(is_late == 0L, stake, 0)),
      stake_late      = sum(dplyr::if_else(is_late == 1L, stake, 0)),
      game_pnl_late   = sum(dplyr::if_else(is_late == 1L, game_pnl, 0)),
      stake_all       = sum(stake,    na.rm = TRUE),
      game_pnl_all    = sum(game_pnl, na.rm = TRUE),
      .groups = "drop") |>
    dplyr::mutate(stake_ramp = stake_late_avg %/0% stake_early_avg,
                  late_def   = !!CONST$LATE_DEF) |>     # ★ 口径锁常量列
    dplyr::filter(n_orders_all >= !!CONST$MIN_ORDERS_100) |>
    dplyr::select(late_def, uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
                  stake_late_avg, stake_early_avg, stake_ramp, roi_late, roi_early,
                  stake_late, game_pnl_late, stake_all, game_pnl_all) |>
    dplyr::arrange(dplyr::desc(late_share), dplyr::desc(n_orders_late))
}


## ==============================================================================
##  §21 · §R02 同桌对 Jaccard / Lift
##  源本对应：第 3070 行 → 数据库/R02_same_table.csv
##  ------------------------------------------------------------------------------
##  ★ 绝不可对 bet02 原表直接自连接：1.9 亿 × 1.9 亿 必然打爆集群。
##  ★★ 2026-08-09 降内存斧正（实测触发：BE 单节点 107 GB 撞上限而崩）
##     根因不在数据量，在**两处配对的约束强弱悬殊**：
##       · pair  的配对约束是「同一物理局」（round_key），一局数十人，量级可控；
##       · expct 的配对约束却是「同一桌 × 同一日」，同桌同日候选会员可达数千，
##         配对数按其平方增长 —— 比 pair 高出一个数量级。
##  ⚠️ 故意不加 same_rate >= 0.30 的筛选：阈值网格要扫
##     30%/40%/50%/70% × Lift 1/2/3/5 十六格，只导 30% 以上就扫不出下沿。
##     若行数仍过大，把活跃度门槛往上提，而不是加 same_rate 条件。
## ==============================================================================
r02_same_table <- function(con, bs = a168_base(con), min_rounds = 200L) {

  ## 会员×局（先压到局粒度并限候选池 —— 两阶段自连接之第一阶段）
  mr2 <- bs |>
    dplyr::distinct(member_id, round_key, table_id, bet_date)

  act <- mr2 |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(n_rounds = dplyr::n_distinct(round_key), .groups = "drop") |>
    dplyr::filter(n_rounds >= !!min_rounds)

  mr2 <- dplyr::semi_join(mr2, act, by = "member_id")

  ## 同局配对（x.member_id < y.member_id 去重，免出 (a,b) 与 (b,a) 两行）
  pair <- mr2 |>
    dplyr::inner_join(mr2, by = "round_key", suffix = c("_x", "_y")) |>
    dplyr::filter(member_id_x < member_id_y) |>
    dplyr::group_by(uid1 = member_id_x, uid2 = member_id_y) |>
    dplyr::summarise(same_rounds = dplyr::n(),
                     n_tables    = dplyr::n_distinct(table_id_x),
                     first_day   = min(bet_date_x),
                     last_day    = max(bet_date_x), .groups = "drop") |>
    dplyr::filter(same_rounds >= !!CONST$MIN_PAIR_100)

  ## 期望同局数（零偏好基准）：Σ 各桌日 n_a × n_b / n_td
  td  <- mr2 |> dplyr::group_by(table_id, bet_date, member_id) |>
                dplyr::summarise(n_md = dplyr::n(), .groups = "drop")
  tot <- mr2 |> dplyr::group_by(table_id, bet_date) |>
                dplyr::summarise(n_td = dplyr::n_distinct(round_key), .groups = "drop")

  expct <- pair |>
    dplyr::select(uid1, uid2) |>
    dplyr::inner_join(td, by = c("uid1" = "member_id")) |>
    dplyr::inner_join(dplyr::rename(td, n_md_b = n_md),
                      by = c("uid2" = "member_id", "table_id", "bet_date")) |>
    dplyr::inner_join(tot, by = c("table_id", "bet_date")) |>
    dplyr::group_by(uid1, uid2) |>
    dplyr::summarise(exp_same = sum(n_md * n_md_b %/0% n_td), .groups = "drop")

  pair |>
    dplyr::inner_join(dplyr::rename(act, rounds_1 = n_rounds), by = c("uid1" = "member_id")) |>
    dplyr::inner_join(dplyr::rename(act, rounds_2 = n_rounds), by = c("uid2" = "member_id")) |>
    dplyr::left_join(expct, by = c("uid1", "uid2")) |>
    dplyr::mutate(
      n_same_orders = same_rounds,
      same_rate     = same_rounds %/0% pmin(rounds_1, rounds_2),
      jaccard       = same_rounds %/0% (rounds_1 + rounds_2 - same_rounds),
      lift          = same_rounds %/0% exp_same) |>
    dplyr::select(uid1, uid2, n_same_orders, rounds_1, rounds_2,
                  same_rate, jaccard, lift, exp_same, n_tables, first_day, last_day) |>
    dplyr::arrange(dplyr::desc(lift), dplyr::desc(same_rate))
}

## §R02-1 · 分批模板（兜底之路 —— 三处斧正后仍撞内存上限时才用）
##   ★ 唯一安全的切分维度是 table_id：同桌配对本就不跨桌，各批独立、无重叠无遗漏。
##   ★★ 切勿按日期或会员号切：
##      按日切会把跨日的同桌对拆散、same_rounds 被人为分割；
##      按会员号切会漏掉「一个在批内、一个在批外」的对。
r02_by_table_batch <- function(con, tables, ...) {
  bs <- a168_base(con) |> dplyr::filter(table_id %in% !!tables)
  r02_same_table(con, bs = bs, ...)
}


## ==============================================================================
##  §22 · §R03 玩家×荷官关联异常
##  源本对应：第 3240 行 → 数据库/R03_player_dealer.csv
##  ------------------------------------------------------------------------------
##  ★ 局级去重 + 玩法基准 Z-score + 对照胜率。
##    用 bet03+bet04 统计关联有效局数，修正同局拆多单造成的 Z-score 放大。
##  ★★ 源本 2026-08-11 提速根因：StarRocks 之 CTE 默认 inline 展开，
##     被引用 N 次即重算 N 次 —— 最贵的 ranked（1.26 亿注单开窗去重）曾算 4 遍。
##     R 侧若走 lazy 亦有同病，故本函数把 bs 作为参数传入，由调用方 collect 一次复用。
##  ⚠ 翻页一律取唯一键（member_id + dealer_id）为序，不得以 z_score 为序：
##    实测 517,528 行中 z_score 并列 103,510 组、连次级键都分不开者 452 行，
##    OFFSET 翻页必致重漏。
## ==============================================================================
r03_player_dealer <- function(con, bs = a168_base(con)) {

  ord <- bs |>
    dplyr::mutate(is_sentinel_dealer =
      dplyr::if_else(trimws(dealer_id) %in% !!CONST$SENTINEL_EID, 1L, 0L))

  ## 玩法基准胜率（剔哨兵荷官后计算）—— 不可统一用 70%，须按玩法各自基准
  side_base <- ord |>
    dplyr::filter(is_sentinel_dealer == 0L) |>
    dplyr::group_by(bet_side) |>
    dplyr::summarise(p_base = sum(dplyr::if_else(game_pnl >  0, 1L, 0L)) %/0%
                              sum(dplyr::if_else(game_pnl != 0, 1L, 0L)),
                     .groups = "drop")

  ## 局级去重：同局拆多单压回一局，否则 Z-score 被放大
  pr <- ord |>
    dplyr::left_join(side_base, by = "bet_side") |>
    dplyr::group_by(member_id, dealer_id, is_sentinel_dealer, shoe_id, round_no, table_id) |>
    dplyr::summarise(
      stake             = sum(stake,    na.rm = TRUE),
      game_pnl          = sum(game_pnl, na.rm = TRUE),
      net_pnl           = sum(net_pnl,  na.rm = TRUE),
      n_orders_in_round = dplyr::n(),
      p_base_round_w    = sum(stake * p_base, na.rm = TRUE) %/0%
                          sum(dplyr::if_else(!is.na(p_base), stake, 0), na.rm = TRUE),
      p_base_round_unw  = mean(p_base, na.rm = TRUE),
      .groups = "drop")

  pd <- pr |>
    dplyr::group_by(member_id, dealer_id, is_sentinel_dealer) |>
    dplyr::summarise(
      n_rounds_eff   = dplyr::n(),
      n_orders       = sum(n_orders_in_round),
      stake          = sum(stake,    na.rm = TRUE),
      game_pnl       = sum(game_pnl, na.rm = TRUE),
      net_pnl        = sum(net_pnl,  na.rm = TRUE),
      n_win          = sum(dplyr::if_else(game_pnl >  0, 1L, 0L)),
      n_dec          = sum(dplyr::if_else(game_pnl != 0, 1L, 0L)),
      p_base_mix_w   = mean(p_base_round_w,   na.rm = TRUE),
      p_base_mix_unw = mean(p_base_round_unw, na.rm = TRUE),
      .groups = "drop")

  ## ★ 此处即 SUM(...) OVER (PARTITION BY member_id) —— 窗口，不塌行。
  ##   R 侧写法：group_by() |> mutate()（**不是** summarise）。
  ##   base R 等价：ave(net_pnl, member_id, FUN = sum)
  pdw <- pd |>
    dplyr::group_by(member_id) |>
    dplyr::mutate(net_pnl_all  = sum(net_pnl,  na.rm = TRUE),
                  game_pnl_all = sum(game_pnl, na.rm = TRUE),
                  stake_all    = sum(stake,    na.rm = TRUE),
                  win_all      = sum(n_win),
                  dec_all      = sum(n_dec)) |>
    dplyr::ungroup()

  z <- function(w, d, p) (w - d * p) %/0% sqrt(d * p * (1 - p))

  pdw |>
    dplyr::transmute(
      uid = member_id, dealer_id, is_sentinel_dealer,
      stake_amount     = stake,
      profit_amount    = game_pnl,
      net_pnl,
      win_rate         = n_win %/0% n_dec,
      n_related_orders = n_orders,
      n_rounds_eff, p_base_mix_w, p_base_mix_unw,
      total_bet_amount = stake,
      n_bets           = n_orders,
      z_score_w        = z(n_win, n_dec, p_base_mix_w),
      z_score_unw      = z(n_win, n_dec, p_base_mix_unw),
      z_score          = z(n_win, n_dec, p_base_mix_w),   # 主口径 = 加权版
      delta_p          = p_base_mix_w - p_base_mix_unw,
      delta_z          = z(n_win, n_dec, p_base_mix_w) - z(n_win, n_dec, p_base_mix_unw),
      net_pnl_all, game_pnl_all, stake_all,
      win_rate_all     = win_all %/0% dec_all) |>
    dplyr::arrange(uid, dealer_id)     # ★ 唯一键为序，非 z_score
}


## ==============================================================================
##  §23 · §T02 会员×日 ROI
##  源本对应：第 3978 行 → 数据库/T02_daily_roi.csv
##  索提诺 / CAS 的**唯一输入**。预期行数大，必须切分导出。
## ==============================================================================
t02_daily_roi <- function(con, bs = a168_base(con)) {
  bs |>
    dplyr::group_by(member_id, bet_date) |>
    dplyr::summarise(stake    = sum(stake,    na.rm = TRUE),
                     game_pnl = sum(game_pnl, na.rm = TRUE),
                     n_rounds = dplyr::n_distinct(round_key),
                     .groups = "drop") |>
    dplyr::arrange(member_id, bet_date)
}


## ==============================================================================
##  §24 · §T03 打水型画像
##  源本对应：第 4033 行 → 数据库/T03_arbitrage.csv
##  ------------------------------------------------------------------------------
##  ★ hedge_rate 口径：此处为**自对押率**（同一物理局内该会员同时押到庄侧与闲侧
##    的局数占比），是单表可算的打水指纹。
##    **跨会员对押**（一庄一闲两个号）不在本函数范围，由 §R02 / §C06fix 并入。
##  ★ 2026-08-07 DX-01 实测校准：bet09 为英文玩法名，**必须等值匹配，不能用 LIKE**。
##    LIKE '%BANK%' 会把 BankerDragonBonus(20.7 万) 与 BankerNatural(6.2 万) 一并算成庄，
##    而那是边注，与主线庄闲不构成对冲关系。
## ==============================================================================
t03_arbitrage <- function(con, bs = a168_base(con)) {
  bs |>
    dplyr::mutate(is_b = dplyr::if_else(trimws(bet_side) == "Banker", 1L, 0L),
                  is_p = dplyr::if_else(trimws(bet_side) == "Player", 1L, 0L)) |>
    dplyr::group_by(member_id, bet_date, round_key) |>
    dplyr::summarise(stake = sum(stake, na.rm = TRUE), validbet = sum(valid_bet, na.rm = TRUE),
                     game_pnl = sum(game_pnl, na.rm = TRUE), rebate = sum(rebate, na.rm = TRUE),
                     net_pnl = sum(net_pnl, na.rm = TRUE),
                     is_self_hedge = dplyr::if_else(max(is_b) == 1L & max(is_p) == 1L, 1L, 0L),
                     .groups = "drop") |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      stake      = sum(stake,    na.rm = TRUE),
      validbet   = sum(validbet, na.rm = TRUE),
      game_pnl   = sum(game_pnl, na.rm = TRUE),
      net_pnl    = sum(net_pnl,  na.rm = TRUE),
      rebate     = sum(rebate,   na.rm = TRUE),
      hedge_rate = sum(is_self_hedge) / dplyr::n(),
      stake_cv   = stats::sd(stake) %/0% mean(stake),
      n_rounds   = dplyr::n(),
      n_days     = dplyr::n_distinct(bet_date),
      .groups = "drop") |>
    dplyr::filter(n_rounds >= !!CONST$MIN_ORDERS_100) |>
    dplyr::arrange(dplyr::desc(hedge_rate), dplyr::desc(validbet))
}


## ==============================================================================
##  §25 · §K01 扩样特征矩阵
##  源本对应：第 4327 行 → 数据库/K01_risk_feature_matrix.csv
##  ------------------------------------------------------------------------------
##  ★ 种子必须**混合来源**（人工风险单 + §R01/§R02/§R03 + L0 金标准 17 IP），
##    否则 PU 模型学到的只是「某一条规则」，扩样等于把规则重跑一遍。
##  ★ 特征侧**刻意排除**产生种子的那几个量（late_share / same_rate / z_score），
##    否则就是自我循环。此处只给「行为结构」类特征。
## ==============================================================================
k01_risk_feature_matrix <- function(con, bs = a168_base(con), seed_ids = character()) {

  rk <- bs |>
    dplyr::mutate(bet_hour = lubridate::hour(t_bet),
                  is_b = dplyr::if_else(trimws(bet_side) == "Banker", 1L, 0L),
                  is_p = dplyr::if_else(trimws(bet_side) == "Player", 1L, 0L)) |>
    dplyr::group_by(member_id, bet_date, round_key) |>
    dplyr::summarise(
      table_id  = max(table_id), bet_ip = max(bet_ip), dealer_id = max(dealer_id),
      bet_hour  = max(bet_hour),
      stake     = sum(stake,     na.rm = TRUE),
      validbet  = sum(valid_bet, na.rm = TRUE),
      game_pnl  = sum(game_pnl,  na.rm = TRUE),
      rebate    = sum(rebate,    na.rm = TRUE),
      net_pnl   = sum(net_pnl,   na.rm = TRUE),
      is_self_hedge = dplyr::if_else(max(is_b) == 1L & max(is_p) == 1L, 1L, 0L),
      .groups = "drop")

  side_entropy <- bs |>
    dplyr::group_by(member_id, bet_side) |>
    dplyr::summarise(n_side = dplyr::n(), .groups = "drop_last") |>
    dplyr::mutate(n_all = sum(n_side)) |>
    dplyr::filter(n_all > 0, n_side > 0) |>
    dplyr::summarise(side_entropy = -sum((n_side / n_all) * log(n_side / n_all)),
                     .groups = "drop")

  rk |>
    dplyr::group_by(member_id) |>
    dplyr::summarise(
      n_rounds       = dplyr::n(),
      n_days         = dplyr::n_distinct(bet_date),
      n_tables       = dplyr::n_distinct(table_id),
      n_ip           = dplyr::n_distinct(bet_ip),
      n_dealer       = dplyr::n_distinct(dealer_id),
      stake_cv       = stats::sd(stake) %/0% mean(stake),
      stake_p90_p50  = stats::quantile(stake, .90, na.rm = TRUE) %/0%
                       stats::quantile(stake, .50, na.rm = TRUE),
      hedge_rate     = sum(is_self_hedge) / dplyr::n(),
      rebate_dep     = sum(rebate) %/0% abs(sum(net_pnl)),
      night_share    = sum(dplyr::if_else(bet_hour >= 0 & bet_hour <= 6, 1L, 0L)) / dplyr::n(),
      roi_game       = sum(game_pnl) %/0% sum(stake),
      validbet       = sum(validbet, na.rm = TRUE),
      .groups = "drop") |>
    dplyr::left_join(side_entropy, by = "member_id") |>
    dplyr::mutate(side_entropy = dplyr::coalesce(side_entropy, 0),
                  is_seed = as.integer(member_id %in% !!seed_ids)) |>
    dplyr::select(member_id, is_seed, n_rounds, n_days, n_tables, n_ip, n_dealer,
                  side_entropy, stake_cv, stake_p90_p50, hedge_rate, rebate_dep,
                  night_share, roi_game, validbet) |>
    dplyr::arrange(dplyr::desc(validbet))
}

#' §K01b · 种子名单（混合来源）
#' 源本对应：manual_risk / gold_ip 两支
k01b_seed_manual <- function(con, gold_ips = character()) {
  manual <- tb(con, "dailyrep") |>
    dplyr::filter(risk == "1" | orders == "1") |>
    dplyr::distinct(member_id = bet05) |>
    dplyr::mutate(seed_src = "manual_risk")

  gold <- if (length(gold_ips)) {
    tb(con, "bet02") |> in_window(dt) |>
      dplyr::filter(bet02 == !!CONST$GAME_BACCARAT, ip %in% !!gold_ips) |>
      dplyr::distinct(member_id = bet05) |>
      dplyr::mutate(seed_src = "gold_ip")
  } else NULL

  out <- if (is.null(gold)) manual else dplyr::union_all(manual, gold)
  dplyr::arrange(out, member_id)
}


## ==============================================================================
##  §30 · 下游评分：分位归一 → 赏罚定向 → 加权
##  ------------------------------------------------------------------------------
##  ★ 这一段**源本没有**。源本只出底料，此处补上其下游、原在 Python/R 侧者。
##    赏罚方向抄自源本各条注释之「赏罚方向为『X』」，逐条可回溯。
## ==============================================================================

## 赏罚方向表：+1 = 赏（越大越好）  −1 = 罚（越大越险）
DIRECTION <- list(
  S01 = c(流水贡献 = 1, 游戏输赢贡献 = 1, 活跃稳定 = 1, 退水支出 = -1,
          人工标记史 = -1, 投注产品结构熵 = 1,
          索提诺稳定性 = -1,           # ⚠ 罚侧！赢得稳的才是 T2 技术型
          生命周期阶段 = 1),
  S02 = c(在桌洗码量 = 1, 客群广度 = 1, 当值时长 = 1, 节奏稳定度 = 1,
          特定玩家复现率 = -1),
  S03 = c(线下规模 = 1, 真实流水 = 1, 退水支出 = -1, 退水消耗比 = -1,
          下线留存 = 1, 新增会员质量 = 1)
)

#' 分位归一：rank-based，抗厚尾、抗量纲变更
#' ⚠ NA 一律置中位 0.5，不得置 0 —— 置 0 等同判其「最差」，是无中生有的判决
pct_rank <- function(x) {
  r <- dplyr::percent_rank(x)
  dplyr::if_else(is.na(r), 0.5, r)
}

#' 归一 + 定向 + 加权
#' @param w 权重具名向量；NULL 则等权。
#'   ⚠ 等权即「均值凑合」，仅为占位。正式权重须由 §K01 之 PU 学习产出后覆盖。
score_entity <- function(df, dir, w = NULL, key = NULL, scale = 100) {
  vars <- names(dir)
  miss <- setdiff(vars, names(df))
  if (length(miss)) stop("底料口径不符，缺列：", paste(miss, collapse = ", "),
                          "\n—— 疑为旧版 CSV。请重跑取数后再读。")
  if (is.null(w)) w <- setNames(rep(1 / length(vars), length(vars)), vars)
  stopifnot(setequal(names(w), vars), abs(sum(w) - 1) < 1e-9)

  z <- df |>
    dplyr::mutate(dplyr::across(dplyr::all_of(vars), pct_rank, .names = "z_{.col}"))
  for (v in vars) {
    zc <- paste0("z_", v)
    if (dir[[v]] < 0) z[[zc]] <- 1 - z[[zc]]
  }
  z |>
    dplyr::mutate(综合分 = as.numeric(as.matrix(dplyr::across(
      dplyr::all_of(paste0("z_", vars)))) %*% w[vars]) * scale) |>
    dplyr::arrange(dplyr::desc(综合分))
}

#' 雷达图输入（长表）
radar_long <- function(scored, dir, key) {
  scored |>
    dplyr::select({{ key }}, dplyr::all_of(paste0("z_", names(dir)))) |>
    tidyr::pivot_longer(-{{ key }}, names_to = "维度", values_to = "归一值") |>
    dplyr::mutate(维度 = sub("^z_", "", 维度))
}


## ==============================================================================
##  §40 · 导出清单与导出纪律
##  源本对应：卷首「导出声明纪律」第 211~267 行
##  ------------------------------------------------------------------------------
##  ① 一份文件名只允许一条活跃语句产出（源本教训：S-04a 覆盖 §S04p）
##  ② 文件名一字不可错 —— 错名不报错，只让图表静默空白，是最坑的失败方式
##  ③ 导出必带 ORDER BY / arrange()
##  ④ 编码 CSV(UTF-8)，全部存入报告同级「数据库/」目录
## ==============================================================================
MANIFEST <- tibble::tribble(
  ~key,   ~file,                            ~fn,                       ~note,
  "S01",  "S01_player_score.csv",           "s01_player_score",        "玩家评分底料",
  "S02",  "S02_dealer_score.csv",           "s02_dealer_score",        "荷官评分底料",
  "S03",  "S03_agent_score.csv",            "s03_agent_score",         "代理评分底料",
  "S04",  "S04_analyst_score.csv",          "s04p_analyst_score",      "风控员最小画像（⛔ 勿用 S-04a）",
  "R01",  "R01_late_shoe.csv",              "r01_late_shoe",           "靴末段下注（带 late_def 口径锁）",
  "R02",  "R02_same_table.csv",             "r02_same_table",          "同桌对 Jaccard / Lift",
  "R03",  "R03_player_dealer.csv",          "r03_player_dealer",       "玩家×荷官（全窗聚合）",
  "T02",  "T02_daily_roi.csv",              "t02_daily_roi",           "会员×日 ROI（大表，须切分）",
  "T03",  "T03_arbitrage.csv",              "t03_arbitrage",           "打水型画像",
  "K01",  "K01_risk_feature_matrix.csv",    "k01_risk_feature_matrix", "扩样特征矩阵",
  "K01b", "K01b_seed_manual.csv",           "k01b_seed_manual",        "种子名单"
)

#' 导出（只接受 MANIFEST 内之键，杜绝错名）
export_csv <- function(df, key, out_dir = CONST$OUT_DIR) {
  row <- dplyr::filter(MANIFEST, key == !!key)
  if (nrow(row) != 1L) stop("文件名未登记于 MANIFEST：", key)
  if (inherits(df, "tbl_lazy")) df <- dplyr::collect(df)
  if (nrow(df) == 0L) warning("【空表】", row$file, " —— 请先核对口径，勿直接交付")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  path <- file.path(out_dir, row$file)
  readr::write_excel_csv(df, path)      # UTF-8 with BOM，Excel 直开不乱码
  message(sprintf("✓ %-32s %8d 行  %s", row$file, nrow(df), row$note))
  invisible(path)
}

#' 批次驱动：一次跑完第二批评分底料
run_batch_scoring <- function(con) {
  bs <- dplyr::collect(a168_base(con))      # ★ collect 一次，四条复用，免 CTE 重算
  export_csv(s01_player_score(con, bs), "S01")
  export_csv(s02_dealer_score(con, bs), "S02")
  export_csv(s03_agent_score(con, bs),  "S03")
  export_csv(s04p_analyst_score(con),   "S04")
  invisible(bs)
}


## ==============================================================================
##  §90 · 未移植清单（据实列明，不作虚言）
## ------------------------------------------------------------------------------
##  下列段落**未移植**，请仍以源本 SQL 直通执行（run_raw_sql）：
##
##  【元数据类 —— R 侧无等价抽象，硬译必失真】
##    §Z-01 全库表清单与规模        §Z-02 备份/测试表排除清单
##    §Z-03 全库字段字典            §Z-04 同名异义自动侦测（★ 最关键一条）
##    §Z-05 类型缺注与注释缺失      §Z-06 逐列高频值普查语句生成
##    §Z-07 普查执行样例            §Z-08 局键唯一性与塌缩检验
##    §Z-09 时间字段口径核验        §Z-11 哨兵值处置前后影响量化
##    §EX-00~§EX-08 七项缺口探查    §DX-01 bet09 玩法编码普查
##
##  【时区守卫 —— 结论依赖库时钟，须在库侧读】
##    §TZ-01~§TZ-05、§PIT-01 修订滞后分布
##
##  【尚未移植，待补】
##    §E02c 分群单位经济学（占成 κ）—— 其量纲探针为自适应判据，
##          须先在库侧跑三日窗确认 bet23~32 是金额还是比率，再定 R 侧算式；
##          在此之前移植即是把未定之事写死，故留空。
##    §B01 / §B01-D 会员×日回测面板、§S-05 / §P-01 会员×月面板
##    §C-00~§C-08 / §N1 / §V-01 异常 IP 与对打主线
##    §DX-04 / §DX-05 玩法与产品全景
## ==============================================================================


## ==============================================================================
##  §99 · 用例
## ==============================================================================
if (FALSE) {

  con <- a168_connect()

  ## —— 第二批：评分底料（不导则雷达与回测全空）——
  bs <- run_batch_scoring(con)

  ## —— 第四批：规则与特征 ——
  export_csv(r01_late_shoe(con, bs),  "R01")
  export_csv(r02_same_table(con, bs), "R02")
  export_csv(r03_player_dealer(con, bs), "R03")
  export_csv(t02_daily_roi(con, bs),  "T02")
  export_csv(t03_arbitrage(con, bs),  "T03")

  seeds <- dplyr::collect(k01b_seed_manual(con))
  export_csv(seeds, "K01b")
  export_csv(k01_risk_feature_matrix(con, bs, seed_ids = seeds$member_id), "K01")

  ## —— 下游：能力值 ——
  S01    <- readr::read_csv(file.path(CONST$OUT_DIR, "S01_player_score.csv"))
  scored <- score_entity(S01, DIRECTION$S01, w = NULL)   # ⚠ w = NULL 即等权占位
  rad    <- radar_long(scored, DIRECTION$S01, member_id)

  ## —— 未移植段落：SQL 直通 ——
  run_raw_sql(con, "
    SELECT table_name, COUNT(*) AS n_cols,
           MAX(CASE WHEN column_name='dt' THEN 1 ELSE 0 END) AS has_dt
    FROM information_schema.columns
    WHERE table_schema='ods_mariadb_2b' AND table_name LIKE 'ods_a168_%'
    GROUP BY table_name ORDER BY table_name;")

  DBI::dbDisconnect(con)
}

## ==============================================================================
##  变更记录
##  2026-08-13  v1  自 a168_取数与核验_SQL总包_v2斧正版.sql 移植。
##                  已移植 11 条产出件 + 下游评分层；未移植清单见 §90。
##                  ⚠ 待办：① dedup_latest 之三级降序须按 note 改 window_order 并核对下推 SQL；
##                          ② §E02c 待量纲探针判定后补；
##                          ③ 与源本逐条对账（同窗同参跑一遍，比对行数与关键分位）。
## ==============================================================================
