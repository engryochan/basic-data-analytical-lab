#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
W-61 · HF9g-P1 编排与注释斧正器（P2 · 零业务变更）

只做三件事，全部为【注释与编排】层面，绝不触碰任何可执行 token：
  T-1  把 §Z 运行前置段（会话参数 SET×8 ＋ PRE-GATE 00A/00B ＋ 导出台账）
       从「第 1 件 A_anchor.csv 的标题注释与其 SQL 之间」上提，独立成段，
       置于全部 129 件之前。可执行语句的先后顺序不变。
  T-2  修正 128 处标题元行中「分区：X（谓词）」之误导写法 ——
       实测全包 x_rec / x_freecomm / x_valid / x_rno / n_side / n_seat
       从未出现在任何 WHERE / AND / HAVING 过滤位，仅出现在 CASE WHEN 内。
  T-3  在 §Z-00 与 BATCH CONTRACT 处补入 W-61 已登记之三条缺陷警示（D-1/D-2/D-3）。

自证：输出文件之【可执行 token 流】必须与输入逐位相同（见 verify_tokens）。
"""
import re
import sys
import hashlib

BANNER_W = "-- " + "═" * 94
BANNER_N = "-- " + "═" * 78


# ──────────────────────────────────────────────────────────────────────────────
# 工具：抽取可执行 token 流（去注释、去字符串外空白），用于等价性自证
# ──────────────────────────────────────────────────────────────────────────────
def strip_line_comment(line):
    """去掉行尾 -- 注释；字符串字面量内的 -- 不算注释。"""
    out, quote, i = [], None, 0
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("'", '"', "`"):
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "-" and i + 1 < len(line) and line[i + 1] == "-":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def token_stream(text):
    """把整份 SQL 归约为一串可执行 token；注释与格式空白全部消失。"""
    exe = "\n".join(strip_line_comment(l) for l in text.split("\r\n"))
    toks = re.findall(r"'(?:[^']|'')*'|\"[^\"]*\"|`[^`]*`|[A-Za-z_][A-Za-z_0-9$]*|\d+\.\d+|\d+|[^\sA-Za-z_0-9]", exe)
    return toks


def token_digest(text):
    toks = token_stream(text)
    return len(toks), hashlib.sha256("\u0001".join(toks).encode("utf-8")).hexdigest()


# ──────────────────────────────────────────────────────────────────────────────
# T-1：定位 §Z 前置段的起讫行（0-based，含首含尾）
# ──────────────────────────────────────────────────────────────────────────────
def locate_preamble(lines):
    """回 (z_start, z_end, insert_at)。三者皆 0-based。"""
    # §Z-00 之横幅上一行即本段起点
    z00 = next(i for i, l in enumerate(lines) if l.startswith("-- §Z-00 · 会话参数"))
    z_start = z00 - 1                       # 起于横幅行
    assert lines[z_start].startswith("-- ═"), "§Z-00 横幅未如预期"

    # 讫于「导出台账」段末横幅之后那条孤立窄横幅
    ledger = next(i for i, l in enumerate(lines) if "导出台账 EXPORT LEDGER" in l)
    z_end = ledger
    while not (lines[z_end].startswith("-- ═") and z_end > ledger):
        z_end += 1                          # 台账段之收尾横幅
    # 再吞掉其后的空行与那条孤立窄横幅
    j = z_end + 1
    while j < len(lines) and (lines[j].strip() == "" or lines[j].startswith("-- ═")):
        if lines[j].startswith("-- ═"):
            z_end = j
        j += 1

    # 第 1 件之标题注释横幅（插入点）
    h1 = next(i for i, l in enumerate(lines) if re.match(r"^--\s+1\.\s+A_anchor\.csv\s+\[", l))
    insert_at = h1 - 1
    assert lines[insert_at].startswith("-- ═"), "第 1 件标题横幅未如预期"
    return z_start, z_end, insert_at


PREAMBLE_HEAD = [
    BANNER_W,
    "-- §Z · 运行前置段 —— 会话参数 ＋ 前置闸 ＋ 导出台账（件号之外，不计入 129 件）",
    "--",
    "--   ★ W-61 编排斧正（2026-08-30）· 本段位置已上提，缘由如下：",
    "--     斧正前，本段被夹在【第 1 件 A_anchor.csv 之标题注释】与【第 1 件自身 SQL】之间，",
    "--     把该件自己的两行前言 ——「-- ── ① 先跑 T_true 留档 ──」与「-- ── ① T_true：…」",
    "--     —— 硬生生劈成两截，中间塞进 8 条 SET ＋ 2 条 PRE-GATE ＋ 一整段导出台账。",
    "--     其害有二：",
    "--       其一，顺读者会把这 10 条可执行语句误认作第 1 件的组成部分；",
    "--       其二，习惯「圈选一件即跑一件」者，或连同会话参数一并误跑，",
    "--             或反过来漏跑会话参数而径跑第 1 件。两者皆为编排之误，非 SQL 之误。",
    "--",
    "--   ★【编排铁律 · 自本版起永久生效】",
    "--     一件 ＝ 一段标题注释 ＋ 紧随其后的一条 SQL 语句。",
    "--     注释在上、语句在下；二者之间不得插入任何其他语句、任何其他段落。",
    "--     会话参数、前置闸、台账、纪律说明，一律归入本 §Z 段，位于全部交付件之前。",
    "--",
    "--   ★ 等价性：可执行语句之先后顺序未变 —— 仍为",
    "--     SET × 8  →  PRE-GATE 00A  →  PRE-GATE 00B  →  第 1 件 …… →  第 129 件。",
    "--     本次调整只搬动注释与段落，token 流逐位相同，输出必然一模一样（已由比对证明）。",
    BANNER_W,
    "",
]

PREAMBLE_TAIL = [
    "",
    BANNER_W,
    "-- §Z 段结束。以下为 129 件交付件。",
    "--   每件恪守【编排铁律】：标题注释在上，SQL 语句在下，中间不夹杂任何他物。",
    BANNER_W,
    "",
]


# ──────────────────────────────────────────────────────────────────────────────
# T-3：D-1 警示（插在第一条 SET 之前）
# ──────────────────────────────────────────────────────────────────────────────
D1_WARN = [
    "--",
    BANNER_N,
    "-- ★ W-61 · D-1 警示（T3·L8·S2 BLOCK）—— 本段 SET 是否生效【不可证】",
    "--   W-58 已实证并登记：StarRocks 的会话状态是【连接级】，而 Superset SQL Lab 走连接池，",
    "--   一次执行与下一次执行未必落在同一条连接。W-58 因此把 @变量 全数内联为字面常量。",
    "--   然而下方 8 条 SET 仍是【独立的会话级语句】—— 与 @变量 属完全同一失效模式。",
    "--   故 2026-08-25（#010/#078）与 2026-08-30（#002）四次 OOM 发生时，",
    "--   `enable_spill` 究竟有无生效，【无证据可考】；缺省态（多数版本为 false）更为可能。",
    "--   ⇒ 处置有二，择一，并记入台账：",
    "--     (a) 把本段 SET 与目标查询【放进同一次提交】（分号分隔、一次执行），",
    "--         使二者必然落在同一连接。此法与下方【一】之「一行一跑」纪律方向相反，",
    "--         若采用，须先改写下方纪律并注明缘由，不得两法并存。",
    "--     (b) 改用随语句走的 Hint：SELECT /*+ SET_VAR(enable_spill = true) */ …",
    "--         Hint 附着于语句本身，不依赖连接池落点，D-1 就此根除。",
    "--         ⚠ 但改 Hint 会改执行计划，可能牵动 PERCENTILE_APPROX 与 NTILE（见 D-3），",
    "--            故只可用于【整件全批次重跑】，绝不可用于补跑某一批。",
    "--   ⇒ 在 (a)/(b) 未择定之前，本段 SET 只能视为【意图声明】，不得当作已生效之保障。",
    BANNER_N,
    "--",
]

# ──────────────────────────────────────────────────────────────────────────────
# T-3：D-2 / D-3 警示（插在 BATCH CONTRACT 段内）
# ──────────────────────────────────────────────────────────────────────────────
D23_WARN = [
    "--",
    "--   ★ W-61 · D-2 警示（T3·L2·S2 BLOCK）—— 分批【不降内存】，只降回传行数",
    "--     audit_rn 由全集排序产生，故 `WHERE z.audit_rn > lo AND <= hi` 在语义上",
    "--     【不可下推】。每一批都必须重扫事实表、重跑去重窗、重跑全部聚合、",
    "--     重跑全部无分区窗口、重跑全局 ROW_NUMBER 排序，然后丢弃 99% 的结果。",
    "--     ⇒ 第 k 批与第 1 批之峰值内存【完全相同】。",
    "--       把批宽由 100000 改到 50000 或 20000，省不了一个字节的 BE 内存。",
    "--       2026-08-30 之两次实测（50000 宽、100000 宽）同样 OOM，即为实证。",
    "--     ⇒ 真正的解法是【算一次，取多次】：先把整件落盘（含 audit_rn），",
    "--       其后每批只是 `SELECT * FROM <落盘件> WHERE audit_rn BETWEEN … ORDER BY audit_rn`。",
    "--",
    "--   ★ W-61 · D-3 警示（T2·L3·S2 BLOCK）—— 跨批次一致性【尚未获证】",
    "--     既然每批独立重算，则两类列并非同一次计算之产物：",
    "--       ① PERCENTILE_APPROX（全包 1,620 处）—— TDigest 之结果依分片与合并次序而定，",
    "--          不保证跨执行逐位重现。本件之 p25/p50/p75/p90/p95/p99 等皆在输出列内。",
    "--       ② NTILE(5) OVER (ORDER BY e.stake)（全包 129 处）—— 排序键单列且非唯一，",
    "--          stake 相等之行落入哪一档取决于输入次序 ⇒ vip_tier 本身即非确定性列。",
    "--     ⇒ 今日之「N 批拼成一份 CSV」，在这两类列上【不能自证为同一数据集】。",
    "--       所谓「两版输出完全一致」，现阶段只是【假设】，不是【已证事实】。",
    "--       落盘一次再分批导出，可把此事从假设升格为构造性事实。",
    "--     （PERCENT_RANK 无此患：并列同秩，确定性。",
    "--       ROW_NUMBER 之排序键若含该件之唯一键，则 audit_rn 亦确定 —— 须逐件核，见 D-8。）",
    "--",
]


# ──────────────────────────────────────────────────────────────────────────────
# T-2：标题元行「分区：」之斧正
# ──────────────────────────────────────────────────────────────────────────────
META_RE = re.compile(r"(分区：)(\S+?)（([^）]*)）")


def fix_meta(line):
    """把『分区：X（谓词）』改写为『派生旗标：X（谓词 · 仅供 CASE 条件聚合，非过滤谓词）』。"""
    def rep(m):
        return "派生旗标：%s（%s · 仅供 CASE 条件聚合，全包无任何 WHERE/AND/HAVING 以此过滤）" % (m.group(2), m.group(3))
    return META_RE.sub(rep, line)


META_NOTE = [
    BANNER_W,
    "-- ★ W-61 · D-9 注记（T1·L7·S3）—— 标题元行「分区：」之写法已斧正",
    "--   斧正前，128 件之标题元行写作『分区：recent（s.x_rec = 1）』一类，形如一条过滤谓词。",
    "--   实测（对全包可执行行逐行判定，排除注释与字符串）：",
    "--     x_rec       可执行行 1,266 处 —— 全数位于 CASE WHEN 之内，WHERE/AND/HAVING 位 0 处",
    "--     x_freecomm  418 处 · x_valid 908 处 · x_rno 209 处 · n_side 39 处 · n_seat 7 处",
    "--                 —— 同样全数不在过滤位",
    "--   ⇒ 该括号内之表达式【从来不是分区条件，而是条件聚合之旗标】。",
    "--     以 #002 B01_bt_panel 为例：窗口仍是全周期 2026-03-21 ~ 2026-08-06，",
    "--     x_rec 只在 st_in / nb_in / net_in / st_out / nb_out / net_out / st_rec / nb_rec",
    "--     等条件求和中充当分支旗标，绝无 `WHERE x_rec = 1` 之事。",
    "--   ⇒ 旧写法会使读者误信「本件只算 recent」，与实际执行范围不符，故改写为「派生旗标」。",
    "--   ⇒ 本次仅改注释措辞，未动一行代码；口径本身是否合理，另行裁定，不在本次范围。",
    BANNER_W,
    "",
]


def apply_patch(text):
    lines = text.split("\r\n")

    # ── T-1 ──
    z_start, z_end, insert_at = locate_preamble(lines)
    assert z_end < insert_at or insert_at < z_start, "区段与插入点不得交叠"
    block = lines[z_start:z_end + 1]

    # ── T-3 · D-1：插在第一条 SET 之前 ──
    first_set = next(i for i, l in enumerate(block) if re.match(r"^SET\s+", l))
    block = block[:first_set] + D1_WARN + block[first_set:]

    # ── T-3 · D-2/D-3：插在 BATCH CONTRACT 之收尾横幅前 ──
    bc = next((i for i, l in enumerate(block) if "BATCH CONTRACT" in l), None)
    if bc is not None:
        k = bc + 1
        while k < len(block) and not block[k].startswith("-- ═"):
            k += 1
        block = block[:k] + D23_WARN + block[k:]

    rest = lines[:z_start] + lines[z_end + 1:]
    # 插入点在移除后重新定位
    ins = next(i for i, l in enumerate(rest) if re.match(r"^--\s+1\.\s+A_anchor\.csv\s+\[", l)) - 1
    out = rest[:ins] + PREAMBLE_HEAD + block + PREAMBLE_TAIL + META_NOTE + rest[ins:]

    # ── T-2 ──
    out = [fix_meta(l) if (l.startswith("--") and "分区：" in l) else l for l in out]
    return "\r\n".join(out)


def main(src, dst):
    raw = open(src, "rb").read().decode("utf-8")
    n0, d0 = token_digest(raw)
    new = apply_patch(raw)
    n1, d1 = token_digest(new)
    ok = (n0, d0) == (n1, d1)
    open(dst, "wb").write(new.encode("utf-8"))
    b = new.encode("utf-8")
    print("%-52s" % src.split("/")[-1])
    print("  token 数  : %d → %d" % (n0, n1))
    print("  token 摘要: %s" % d0[:32])
    print("            %s" % d1[:32])
    print("  等价性    : %s" % ("PASS · 可执行 token 流逐位相同" if ok else "FAIL"))
    print("  新件      : 行数 %d · 字节 %d · CRLF %d · MD5 %s"
          % (b.count(b"\r\n"), len(b), b.count(b"\r\n"), hashlib.md5(b).hexdigest()))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
