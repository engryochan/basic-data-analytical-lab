# -*- coding: utf-8 -*-
"""
a168 · Declaration-vs-Code 一致性检查器 v1
架构铁律（REDTEAM Meta-Gate）：
    FACT                = machine-observed
    SEMANTIC / WAIVER   = human-declared   ← 本脚本绝不生成
    CONSISTENCY         = machine-validated ← 本脚本唯一职责
本脚本永不推定 WAIVED；无人工豁免理由者一律判 FAIL。

用法：
    python a168_declaration_vs_code_validator_v1.py <总包.sql> <已填矩阵.csv> [输出.csv]
"""
import sys, csv, re, hashlib

GATES = [  # (矩阵列名, 判据正则)  —— 正则须先过 selftest 方可使用
    ("Identity_bet02",       r"bet02\s*=\s*'101'"),
    ("Identity_rn",          r"ROW_NUMBER\(\)\s*OVER[\s\S]{0,200}?PARTITION\s+BY\s+\w*\.?bet01[\s\S]*?\brn\s*=\s*1\b"),
    ("Population_age022",    r"age022\s*=\s*'1'"),
    ("Population_category",  r"category\s*=\s*'1'"),
    ("State_bet38",          r"UPPER\(\s*TRIM\(\s*\w*\.?bet38\s*\)\s*\)\s*=\s*'N'"),
    ("Quality_bet05gt0",     r"bet05[^\n]{0,60}>\s*0"),
    ("Quality_bet08notnull", r"NULLIF\(\s*TRIM\(\s*\w*\.?bet08\s*\)[^\n]*IS\s+NOT\s+NULL"),
    ("Quality_bet11gt0",     r"bet11[^\n]{0,60}>\s*0"),
    ("Quality_bet04gt0",     r"bet04[^\n]{0,60}>\s*0"),
    ("Window_dt",            r"dt\s*>=\s*'20\d\d-\d\d-\d\d'"),
    ("Stability_orderby",    r"\bORDER\s+BY\b"),
]
SELFTEST = {  # 正则自验：须在已知真值处命中，否则拒绝运行（Validator Must Be Validated）
    "Identity_bet02": 3300, "Identity_rn": 3300, "Population_age022": 3290,
    "Population_category": 3320, "State_bet38": 3320, "Window_dt": 3300,
}

def load_sql(path):
    raw = open(path, "rb").read()                      # 二进制读：文本模式会把 CRLF 归一为 LF，
    md5_file = hashlib.md5(raw).hexdigest()            # 致 MD5 与文件真值不符（六元组铁律）
    txt = raw.decode("utf-8")
    md5_lf = hashlib.md5(txt.replace("\r\n", "\n").encode("utf-8")).hexdigest()
    eol = "CRLF" if b"\r\n" in raw else "LF"
    return txt.splitlines(), md5_file, md5_lf, eol, len(raw)

DOC_LINES = {172, 344, 345, 346, 8557, 9335}           # 体例说明行，非锚

def all_anchors(lines):
    """段边界须以【全部】导出锚为界（含「不需要」者）——只用受检条目为界，
       会令段落吞并其后之诊断语句，制造伪 PASS。此为 v1 之实测缺陷。"""
    return [i for i, l in enumerate(lines, 1)
            if "\u25b8 \u5bfc\u51fa" in l and i not in DOC_LINES]

def selftest(lines):
    bad = []
    for col, ln in SELFTEST.items():
        pat = dict(GATES)[col]
        window = "\n".join(lines[max(0, ln - 60):ln + 60])
        if not re.search(pat, window, re.I):
            bad.append(col)
    return bad

def segment(lines, anchor, anchors):
    end = min([a for a in anchors if a > anchor] + [len(lines) + 1])
    return "\n".join(lines[anchor - 1:end - 1])

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(2)
    sql_path, mat_path = sys.argv[1], sys.argv[2]
    out_path = sys.argv[3] if len(sys.argv) > 3 else "declaration_check_result.csv"
    lines, md5_file, md5_lf, eol, nbytes = load_sql(sql_path)
    bad = selftest(lines)
    if bad:
        print("⛔ 正则自验失败，拒绝运行：" + "、".join(bad)); sys.exit(1)
    print(f"✓ 正则自验通过")
    print(f"  六元组：行数 {len(lines)} ｜ 字节 {nbytes} ｜ 换行 {eol} "
          f"｜ MD5(file) {md5_file} ｜ MD5(LF) {md5_lf}")

    rows = list(csv.DictReader(open(mat_path, encoding="utf-8-sig")))
    anchors = all_anchors(lines)                        # ← 非仅受检条目
    res, tally = [], {"PASS": 0, "WAIVER_DECLARED": 0, "FAIL": 0, "DECLARATION_MISMATCH": 0}
    skipped = 0
    for r in rows:
        anc = (r.get("锚行") or "").strip()
        if not anc.isdigit():                   # 示例行／注记行：跳过，不参与判定
            skipped += 1
            continue
        body = segment(lines, int(anc), anchors)
        reason = (r.get("豁免理由(人工填写·必填)") or "").strip()
        for col, pat in GATES:
            declared = (r.get(col) or "").strip()          # 人工/事实层登记：有 / 缺
            actual   = "有" if re.search(pat, body, re.I) else "缺"
            if declared and declared != actual:
                v = "DECLARATION_MISMATCH"                  # 声明与代码不符 —— 最高优先
            elif actual == "有":
                v = "PASS"
            elif reason and col.split("_")[-1] in reason:   # 豁免理由须点名该 Gate
                v = "WAIVER_DECLARED"
            else:
                v = "FAIL"
            tally[v] += 1
            res.append({"锚行": r["锚行"], "交付件": r["交付件"], "族": r.get("族", ""),
                        "Gate": col, "声明": declared, "代码": actual, "定谳": v})
    with open(out_path, "w", newline="", encoding="utf-8-sig") as fh:
        w = csv.DictWriter(fh, fieldnames=list(res[0].keys())); w.writeheader(); w.writerows(res)
    print(f"✓ 已出 {len(res)} 条判定 → {out_path}"
          + (f"（跳过示例／注记行 {skipped} 行）" if skipped else ""))
    for k in ("PASS", "WAIVER_DECLARED", "FAIL", "DECLARATION_MISMATCH"):
        print(f"   {k:22}{tally[k]:>5}")
    if tally["DECLARATION_MISMATCH"]:
        print("⚠ 存在声明—代码不符，须优先厘清：声明错抑或代码错，二者皆不得默认为准。")

if __name__ == "__main__":
    main()
