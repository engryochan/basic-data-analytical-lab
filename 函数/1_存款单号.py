import os
import warnings
import pymysql
import pandas as pd

warnings.filterwarnings('ignore')


DEFAULT_MYSQL_CONFIG = {
    'host':     '18.178.159.230',
    'port':     3366,
    'user':     'bigdata',
    'password': 'uvb5SOSmLH8sCoSU',
    'database': 'finance_1000',
}

COLUMN_RENAME_MAP = {
    'id': 'ID', 'site_id': '站点ID', 'member_id': '会员ID', 'member_username': '会员用户名',
    'member_real_name': '会员真实姓名', 'member_grade': '会员等级', 'top_id': '上级ID',
    'bill_no': '账单号', 'typay_order_id': '通用支付订单号', 'order_amount': '订单金额',
    'pay_amount': '实际支付金额', 'pay_seq': '支付流水号', 'rebate_amount': '返利金额',
    'score_amount': '积分金额', 'category': '类别', 'pay_type': '支付方式', 'flow_ratio': '流水比例',
    'pay_status': '支付状态', 'client_type': '客户端类型', 'client_ip': '客户端IP',
    'desposit_name': '充币名称', 'recipient_name': '收款人名称', 'recipient_bank': '收款银行',
    'recipient_address': '收款地址', 'recipient_account': '收款账号', 'recipient_code': '收款码',
    'recipient_bank_name': '收款银行名称', 'pay_result': '支付结果', 'confirm_at': '确认时间',
    'admin_id': '管理员ID', 'created_at': '创建时间', 'updated_at': '更新时间',
    'pay_channel': '支付渠道', 'pay_channel_index': '支付渠道索引', 'remark': '备注',
    'paid_amount': '已支付金额', 'paid_usdt_amount': '已支付USDT金额', 'order_status': '订单状态',
    'transfer_account': '转账账号', 'deposit_account': '充币账号', 'finance_remark': '财务备注',
    'pay_time': '支付时间', 'operator': '操作员', 'complete_time': '完成时间',
    'order_source': '订单来源', 'merchant_no': '商户号', 'data_route': '数据路由',
    'pay_operator': '支付渠道操作员', 'protocol': '协议', 'expected_usdt': '预期USDT',
    'exchange_usdt': '兑换USDT', 'app_id': 'APPID', 'xs_s1': '扩展字段1',
    'xs_s2': '扩展字段2', 'xs_s3': '扩展字段3', 'xs_s8': '扩展字段8', 'xs_s11': '扩展字段11',
    'xs_s12': '扩展字段12', 'xs_s13': '扩展字段13', 'xs_s15': '扩展字段15',
    'credit_rating': '信用评级', 'credit_level': '信用等级', 'reward_rate': '奖励比例',
    'reward_amount': '奖励金额', 'reminder': '提醒', 'request_source': '请求来源',
    'device_no': '设备号', 'is_first_deposit': '是否首充',
    'device_no_success_count': '设备号成功次数', 'client_ip_success_count': '客户端IP成功次数',
    'client_ip_location': '客户端IP位置', 'client_type_x': '客户端类型X', 'rn': 'rn'
}

OUTPUT_COLUMNS = [
    '站点ID', '会员ID', '会员用户名', '会员等级', '上级ID', '账单号', '通用支付订单号',
    '订单金额', '实际支付金额', '支付流水号', '返利金额', '积分金额', '类别', '支付方式',
    '流水比例', '支付状态', '支付结果', '创建时间', '确认时间', '操作员', '完成时间',
]


PAY_TYPE_MAP = {
    1001: "银行卡转账", 1002: "支付宝", 1003: "虚拟币扫码",
    10205: "财务手动上分", 891: "站点代客充值", 49999: "额度代存",
    39999: "佣金代存", 890: "代客充值", 1004: "数字人民币", 1005: "微信",
    1006: "MPay", 1007: "银联快捷", 1008: "IPay", 1009: "银联扫码",
    1010: "云闪付扫码", 1011: "极速支付宝", 1012: "极速数字人民币",
    1013: "支付宝转卡", 1014: "云闪付转卡", 1015: "大额充值", 1016: "京东支付",
    1020: "支付宝h5", 1027: "FPAY钱包", 1028: "OKPAY钱包", 1029: "TOPAY钱包",
    1030: "GOPAY钱包", 1031: "808钱包", 1017: "支付宝小荷包", 1018: "EBPay",
    1019: "极速微信", 1021: "988钱包", 1022: "JD钱包", 1023: "C币钱包",
    1024: "K豆钱包", 1025: "钱能钱包", 1026: "TG钱包", 1032: "网银转账",
    1033: "万币钱包", 1034: "365钱包", 1035: "ABPAY钱包", 1036: "WePay钱包",
    1037: "汇旺支付", 1039: "钱通钱包", 1040: "234钱包",
}
PAY_STATUS_MAP = {
    1: "发起", 2: "确认", 3: "已对账", 4: "用户关闭", 5: "订单失效(45分钟)",
}
CATEGORY_MAP = {
    0: "代客充值", 1: "会员存款", 2: "后台手动上分",
    3: "佣金(代充)钱包转入充值", 6: "代理存款",
}


def export_deposits(start_time: str, end_time: str,
                    site_ids=None,
                    output_dir: str = None,
                    mysql_config: dict = None,
                    output_filename: str = None):

    cfg = dict(DEFAULT_MYSQL_CONFIG)
    if mysql_config:
        cfg.update(mysql_config)

    if output_dir is None:
        output_dir = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(output_dir, exist_ok=True)

    print(f"📡 连接 MySQL {cfg['host']}:{cfg['port']}/{cfg['database']}...")
    conn = pymysql.connect(**cfg)
    print(f"🔍 查询存款记录 {start_time} ~ {end_time}...")

    query = (
        f"SELECT * FROM {cfg['database']}.finance_pay_records "
        f"WHERE pay_status IN (2, 3) "
        f"AND confirm_at BETWEEN '{start_time}' AND '{end_time}';"
    )
    df = pd.read_sql_query(query, conn)
    conn.close()
    print(f"✅ 查询完成: {len(df):,} 行")

    if df.empty:
        print("⚠️ 查询结果为空，未生成文件。")
        return df, []

    df.rename(columns=COLUMN_RENAME_MAP, inplace=True)
    keep = [c for c in OUTPUT_COLUMNS if c in df.columns]
    df = df[keep].copy()

    if '支付方式' in df.columns:
        df['支付方式'] = df['支付方式'].map(lambda v: PAY_TYPE_MAP.get(v, v))
    if '支付状态' in df.columns:
        df['支付状态'] = df['支付状态'].map(lambda v: PAY_STATUS_MAP.get(v, v))
    if '类别' in df.columns:
        df['类别'] = df['类别'].map(lambda v: CATEGORY_MAP.get(v, v))

    files = []
    site_ids = [int(s) for s in site_ids] if site_ids else None

    if site_ids:
        for sid in site_ids:
            sub = df[df['站点ID'] == sid]
            if sub.empty:
                print(f"ℹ️ 站点 {sid} 无数据，跳过。")
                continue
            fn = output_filename if output_filename else f"存款单号_{sid}_{start_time[:10]}_{end_time[:10]}.xlsx"
            fp = os.path.join(output_dir, fn)
            sub.to_excel(fp, index=False)
            files.append(fp)
            print(f"✅ 已输出 {fp}（{len(sub):,} 行）")
    else:
        fn = output_filename or f"存款单号_全部站点_{start_time[:10]}_{end_time[:10]}.xlsx"
        fp = os.path.join(output_dir, fn)
        df.to_excel(fp, index=False)
        files.append(fp)
        print(f"✅ 已输出 {fp}（{len(df):,} 行，全部站点）")

    return df, files


START_TIME = '2026-07-17 00:00:00'
END_TIME   = '2026-07-17 23:59:59'
SITE_IDS   = [] # 空列表 [] 或 None = 全部站点


def main():
    df, files = export_deposits(
        start_time=START_TIME,
        end_time=END_TIME,
        site_ids=SITE_IDS,
    )
    print(f"\n所有站点数据处理完毕，共生成 {len(files)} 个文件。")
    return df, files


if __name__ == "__main__":
    main()
