# -*- coding: utf-8 -*-
"""
数据处理_提款单号.py — 查询 finance_withdraw 表的提款记录

【函数接口】
    export_withdraws(start_time, end_time, site_ids=None, output_dir=None,
                     mysql_config=None) -> (df, files)
    主要供 Kairos GUI 调用，参数化、可重入。

【单独运行】
    直接执行本脚本（python 数据处理_提款单号.py）会调用 main()，
    读取本文件顶部的「单独运行配置」常量。

【输出】
    每个站点一个 .xlsx 文件；若 site_ids=[] 或 None 则全部站点合并为一个文件。
"""

import os
import warnings
import pymysql
import pandas as pd

warnings.filterwarnings('ignore')

# ==============================================================================
# 默认 MySQL 配置（也可由 export_withdraws(mysql_config=...) 覆盖）
# ==============================================================================
DEFAULT_MYSQL_CONFIG = {
    'host':     '18.178.159.230',
    'port':     3366,
    'user':     'bigdata',
    'password': 'uvb5SOSmLH8sCoSU',
    'database': 'finance_1000',
}

# ==============================================================================
# 列名映射：英文 → 中文
# ==============================================================================
COLUMN_RENAME_MAP = {
    'id': 'ID', 'site_id': '站点ID', 'member_id': '会员ID', 'member_username': '会员用户名',
    'phone': '手机号', 'member_grade': '会员等级', 'client_type': '客户端类型',
    'client_ip': '客户端IP', 'bill_no': '账单号', 'typay_order_id': '通用支付订单号',
    'amount': '订单金额', 'usdt_amount': '实际支付金额',
    'preview_deposit': '预存款', 'preview_deposit_time': '预存款时间',
    'preview_success_num': '预存款成功次数', 'bank_code': '银行代码',
    'bank_card': '银行卡号', 'bank_realname': '银行真实姓名', 'category': '类别',
    'draw_status': '提现状态', 'risk_admin_id': '风控管理员ID',
    'risk_confirm_at': '风控确认时间', 'draw_comment': '提现备注',
    'confirm_at': '确认时间', 'top_id': '上级ID', 'created_at': '创建时间',
    'updated_at': '更新时间', 'bank_address': '银行地址',
    'auto_risk_result': '自动风控结果', 'risk_comment': '风控备注',
    'denial_reason': '拒绝原因', 'denial_content': '拒绝内容',
    'hold_reason': '暂扣原因', 'hold_at': '暂扣时间', 'pay_channel': '支付渠道',
    'withdraw_type': '提现类型', 'pay_channel_index': '支付渠道索引',
    'payment_time': '支付时间', 'order_status': '订单状态', 'send_count': '发货次数',
    'bank_created_at': '银行创建时间', 'risk_admin_name': '风控管理员姓名',
    'hold_name': '暂扣姓名', 'member_real_name': '会员真实姓名',
    'risk_operater': '风控操作员', 'finance_remark': '财务备注',
    'merchant_no': '商户号', 'data_route': '数据路由', 'device_no': '设备号',
    'risk_receive_at': '风控接收时间', 'protocol': '协议', 'exchange_rate': '兑换汇率',
    'expected_digiccy': '预期币种', 'handling_fee': '手续费',
    'xs_s0': '扩展字段0', 'xs_s1': '扩展字段1', 'xs_s2': '扩展字段2',
    'xs_s3': '扩展字段3', 'xs_s4': '扩展字段4', 'xs_s8': '扩展字段8',
    'credit_rating': '信用评级', 'credit_level': '信用等级', 'reminder': '提醒',
    'request_source': '请求来源', 'sys_type': '系统类型',
    'sys_type_info': '系统类型信息', 'payment_group_name': '支付组名称',
    'pre_withdraw': '预提现', 'operator': '操作员', 'pay_admin_id': '支付管理员ID',
    'reward_amount': '奖励金额', 'transfer_member_id': '转账会员ID',
    'transfer_member_name': '转账会员姓名', 'risk_c_admin_id': '风控C管理员ID',
    'site_audit_status': '站点审核状态', 'site_audit_remark': '站点审核备注',
    'site_audit_confirm_at': '站点审核确认时间',
    'site_audit_admin_id': '站点审核管理员ID',
    'site_audit_admin_name': '站点审核管理员姓名',
}

# 最终输出保留的列（中文名）
OUTPUT_COLUMNS = [
    '站点ID', '会员ID', '会员用户名', '会员等级', '账单号', '通用支付订单号',
    '订单金额', '实际支付金额', '预存款', '预存款时间', '预存款成功次数',
    '类别', '提现状态', '风控管理员ID', '风控确认时间', '提现备注', '确认时间',
    '上级ID', '创建时间', '更新时间', '自动风控结果', '风控备注', '拒绝原因',
    '拒绝内容', '暂扣原因', '暂扣时间', '支付渠道', '提现类型', '支付渠道索引',
    '支付时间', '订单状态', '发货次数', '银行创建时间', '风控管理员姓名',
    '风控操作员', '财务备注', '商户号', '设备号', '风控接收时间',
    '兑换汇率', '预期币种', '手续费', '信用评级', '信用等级', '提醒',
    '请求来源', '系统类型', '系统类型信息', '支付组名称', '预提现',
    '操作员', '支付管理员ID', '奖励金额', '转账会员ID', '转账会员姓名',
]

# ==============================================================================
# 编码字段 → 中文映射
# ==============================================================================
DRAW_STATUS_MAP = {
    101: "发起，已扣款", 200: "风控计算流水中",
    201: "自动风控不过，等待人工风控", 202: "人工审核挂起",
    300: "已风控,待付款", 401: "自动出款中",
    402: "已付款，提款成功", 403: "已对账，提款成功",
    500: "已拒绝", 501: "出款失败",
}
CATEGORY_MAP = {
    1: "会员中心钱包提款", 3: "代理钱包提款", 5: "虚拟币钱包提款",
    11: "手动下分", 12: "代客下分",
}
WITHDRAW_TYPE_MAP = {
    2001: "提款至银行卡", 20202: "提款至中心钱包", 20203: "佣金转账",
    20204: "额度转账", 20205: "额度代存", 20206: "佣金代存",
    20207: "额度手动下分", 2002: "提款至虚拟币账户", 20209: "代客提款",
    1006: "Mpay钱包", 1008: "IPAY钱包", 1018: "EBPAY钱包", 1021: "988钱包",
    1022: "JD钱包", 1023: "C币钱包", 1024: "K豆钱包", 1025: "钱能钱包",
    1026: "TG钱包", 1027: "FPAY钱包", 1028: "OKPAY钱包", 1029: "TOPAY钱包",
    1030: "GOPAY钱包", 1031: "808钱包", 1033: "万币钱包", 1034: "365钱包",
    1035: "ABPAY钱包", 1036: "WePay钱包", 1037: "汇旺支付", 1002: "支付宝提款",
    1039: "钱通钱包", 1040: "234钱包", 0: "手动下分",
}


def export_withdraws(start_time: str, end_time: str,
                     site_ids=None,
                     output_dir: str = None,
                     mysql_config: dict = None,
                     output_filename: str = None):
    """
    查询提款记录并导出 Excel。

    :param start_time:   开始时间，格式 'YYYY-MM-DD HH:MM:SS'
    :param end_time:     结束时间，格式 'YYYY-MM-DD HH:MM:SS'
    :param site_ids:     站点ID列表（如 ['2000','9015']）；None/空 = 全部站点合并输出一个文件
    :param output_dir:   输出目录，默认脚本所在目录
    :param mysql_config: MySQL 连接参数（用 DEFAULT_MYSQL_CONFIG 的默认值）
    :param output_filename: 当 site_ids 为空时使用的文件名（不含目录），
                            由调用方（console2_app.py）传入含站点名的完整文件名
    :return: (df_after_rename_and_map, [生成文件路径列表])
    """
    cfg = dict(DEFAULT_MYSQL_CONFIG)
    if mysql_config:
        cfg.update(mysql_config)

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(output_dir, exist_ok=True)

    print(f"📡 连接 MySQL {cfg['host']}:{cfg['port']}/{cfg['database']}...")
    conn = pymysql.connect(**cfg)
    print(f"🔍 查询提款记录 {start_time} ~ {end_time}...")

    query = (
        f"SELECT * FROM {cfg['database']}.finance_withdraw "
        f"WHERE draw_status IN (402, 403) "
        f"AND confirm_at BETWEEN '{start_time}' AND '{end_time}';"
    )
    df = pd.read_sql_query(query, conn)
    conn.close()
    print(f"✅ 查询完成: {len(df):,} 行")

    if df.empty:
        print("⚠️ 查询结果为空，未生成文件。")
        return df, []

    # 重命名 + 筛选列
    df.rename(columns=COLUMN_RENAME_MAP, inplace=True)
    keep = [c for c in OUTPUT_COLUMNS if c in df.columns]
    df = df[keep].copy()

    # 编码字段 → 中文（未在映射中的保留原值）
    if '提现状态' in df.columns:
        df['提现状态'] = df['提现状态'].map(lambda v: DRAW_STATUS_MAP.get(v, v))
    if '类别' in df.columns:
        df['类别'] = df['类别'].map(lambda v: CATEGORY_MAP.get(v, v))
    if '提现类型' in df.columns:
        df['提现类型'] = df['提现类型'].map(lambda v: WITHDRAW_TYPE_MAP.get(v, v))

    files = []
    site_ids = [int(s) for s in site_ids] if site_ids else None

    if site_ids:
        for sid in site_ids:
            sub = df[df['站点ID'] == sid]
            if sub.empty:
                print(f"ℹ️ 站点 {sid} 无数据，跳过。")
                continue
            # output_filename 直接使用（由调用方负责生成含站点名的文件名）
            fn = output_filename if output_filename else f"提款单号_{sid}_{start_time[:10]}_{end_time[:10]}.xlsx"
            fp = os.path.join(output_dir, fn)
            sub.to_excel(fp, index=False)
            files.append(fp)
            print(f"✅ 已输出 {fp}（{len(sub):,} 行）")
    else:
        fn = output_filename or f"提款单号_全部站点_{start_time[:10]}_{end_time[:10]}.xlsx"
        fp = os.path.join(output_dir, fn)
        df.to_excel(fp, index=False)
        files.append(fp)
        print(f"✅ 已输出 {fp}（{len(df):,} 行，全部站点）")

    return df, files


# ==============================================================================
# 单独运行配置（仅 `python 数据处理_提款单号.py` 时使用）
# ==============================================================================
START_TIME = '2025-12-02 00:00:00'
END_TIME   = '2025-12-02 23:59:59'
# 站点ID列表：空列表 [] 或 None = 全部站点；指定多个用列表如 [2000, 9015]
SITE_IDS   = [2000]


def main():
    """单独运行入口。"""
    df, files = export_withdraws(
        start_time=START_TIME,
        end_time=END_TIME,
        site_ids=SITE_IDS,
    )
    print(f"\n所有站点数据处理完毕，共生成 {len(files)} 个文件。")
    return df, files


if __name__ == "__main__":
    main()
