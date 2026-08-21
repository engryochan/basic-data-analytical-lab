# -*- coding: utf-8 -*-
"""
a168 · Namespace Gate v1 —— 交付集合身份之机械化保护
=====================================================================
职责（唯一）：证明「数据库/ 里的东西」与「登记册里的集合」是同一个集合。

REDTEAM 禁止模式（本器拒绝实现）：
    交付件发现范围 = 项目根递归 *.csv          ⛔ 禁止
    交付件发现范围 = 数据库/ 顶层（非递归）     ✅ 唯一合法

理由：审计工装（审计/**）、执行函数（函数/*.R）、中间档，皆产 .csv／.json，
      递归扫描会把它们计入交付件，令集合身份 v10-93 静默膨胀为 94、95……
      而计数变化往往不被察觉——「集合漂移而数量不漂移」之反面，同样致命。

四态判定：
    IN_SET           登记有、盘上有            → 正常
    MISSING          登记有、盘上无            → 交付件缺失（未导出／被删／改名）
    UNREGISTERED     盘上有、登记无            → NON_DELIVERY_ARTIFACT 混入
    NAMESPACE_LEAK   登记名出现于 数据库/ 之外  → 命名空间泄漏

用法：
    python a168_namespace_gate_v1.py <项目根> <集合身份登记.json> [集合名]
    集合名默认 v10-93；可传 v11-91 等。
"""
import sys, os, json, hashlib

DELIVERY_DIR = "数据库"          # 唯一合法交付命名空间
AUDIT_DIRS   = ("审计", "函数")   # 明示之非交付命名空间（仅供报告分类）


def fingerprint(names):
    """集合身份 = COUNT + 成员名排序后之摘要。数字不是身份，集合才是身份。"""
    blob = "\n".join(sorted(names)).encode("utf-8")
    return len(names), hashlib.md5(blob).hexdigest()[:12], hashlib.sha256(blob).hexdigest()[:12]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    root, reg_path = sys.argv[1], sys.argv[2]
    set_name = sys.argv[3] if len(sys.argv) > 3 else "v10-93"

    reg = json.load(open(reg_path, encoding="utf-8"))
    if set_name not in reg:
        print(f"⛔ 登记册无此集合：{set_name}；可选 {sorted(reg)}")
        sys.exit(1)
    registered = set(reg[set_name])

    ddir = os.path.join(root, DELIVERY_DIR)
    if not os.path.isdir(ddir):
        print(f"⛔ 未找到交付命名空间：{ddir}")
        sys.exit(1)

    # 只看 数据库/ 顶层，不递归 —— 递归即禁止模式
    on_disk = {f for f in os.listdir(ddir) if os.path.isfile(os.path.join(ddir, f))}

    in_set       = sorted(registered & on_disk)
    missing      = sorted(registered - on_disk)
    unregistered = sorted(on_disk - registered)

    # 命名空间泄漏：登记名出现在 数据库/ 之外
    leaks = []
    for dirpath, _, files in os.walk(root):
        if os.path.abspath(dirpath) == os.path.abspath(ddir):
            continue
        for f in files:
            if f in registered:
                leaks.append(os.path.relpath(os.path.join(dirpath, f), root))

    n_r, m_r, s_r = fingerprint(registered)
    n_d, m_d, s_d = fingerprint(on_disk)

    print(f"集合身份检核 · {set_name}")
    print(f"  登记册 : COUNT {n_r:>3} ｜ MD5-12 {m_r} ｜ SHA256-12 {s_r}")
    print(f"  盘  上 : COUNT {n_d:>3} ｜ MD5-12 {m_d} ｜ SHA256-12 {s_d}")
    same = (registered == on_disk)
    print(f"  裁定   : {'✅ 集合一致，身份闭合' if same else '⛔ 集合不一致 —— 身份未闭合'}")
    if not same and n_r == n_d:
        print("  ⚠ 撞数陷阱：基数相同而集合相异——最易被误认为『还是原来那一批』。")

    def block(title, items, tag):
        if not items:
            return
        print(f"\n【{title}】{len(items)} 件  [{tag}]")
        for x in items:
            print(f"   · {x}")

    block("MISSING · 登记有、盘上无", missing, "交付件缺失")
    block("UNREGISTERED · 盘上有、登记无", unregistered, "NON_DELIVERY_ARTIFACT")
    block("NAMESPACE_LEAK · 登记名现于 数据库/ 之外", leaks, "命名空间泄漏")

    if unregistered:
        print("\n⛔ 处置：混入之档一律移出 数据库/ ——")
        print("   审计工装 → 审计/  ｜  执行函数 → 函数/  ｜  中间档 → 项目外或 tmp/")
        print("   若确为新交付件，须先经登记（新集合身份、新指纹），方可入内。")

    sys.exit(0 if same and not leaks else 1)


if __name__ == "__main__":
    main()
