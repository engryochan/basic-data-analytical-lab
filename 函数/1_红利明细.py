from sqlalchemy import create_engine
import pandas as pd

# 红利数据
start_date = '2025-04-01 00:00:00'  # 开始时间
end_date = '2025-04-18 23:59:59'    # 结束时间
site_id = '7000'  # 站点ID

engine = create_engine("mysql+pymysql://bigdata:uvb5SOSmLH8sCoSU@18.178.159.230:3366/activity_1000")

# 红利数据 updated_at = 发放时间 、 created_at = 申请时间
query1 = f"""
SELECT * FROM activity_1000.member_dividend
where updated_at between '{start_date} 00:00:00' and '{end_date} 23:59:59'
and status = 2 and category not in (999555)
and site_id = {site_id};
"""

daily_promo = pd.read_sql_query(query1, engine)
# print(daily_promo.head())

# daily_promo.columns = ['activity_id','activity_title','activity_type','after_money','applicant',
# 'applicant_remark','before_money','bill_no','category','check_remark',
# 'check_user','created_at','flow_amount','flow_limit','flow_times',
# 'id','issue_type','member_grade','member_id','member_name',
# 'money','receive_mode','site_id','status','top_id',
# 'updated_at','venue_id','wallet_category']

daily_promo.rename(columns={'activity_id': '活动ID'}, inplace=True)
daily_promo.rename(columns={'activity_title': '活动标题'}, inplace=True)
daily_promo.rename(columns={'activity_type': '活动类型'}, inplace=True)
daily_promo.rename(columns={'after_money': '活动后金额'}, inplace=True)
daily_promo.rename(columns={'applicant': '操作人'}, inplace=True)
daily_promo.rename(columns={'applicant_remark': '申请备注'}, inplace=True)
daily_promo.rename(columns={'before_money': '活动前金额'}, inplace=True)
daily_promo.rename(columns={'bill_no': '订单号'}, inplace=True)
daily_promo.rename(columns={'category': '类别'}, inplace=True)
daily_promo.rename(columns={'check_remark': '审核备注'}, inplace=True)

daily_promo.rename(columns={'check_user': '审核用户'}, inplace=True)
daily_promo.rename(columns={'created_at': '申请时间'}, inplace=True)
daily_promo.rename(columns={'flow_amount': '流水金额'}, inplace=True)
daily_promo.rename(columns={'flow_limit': '流水限额'}, inplace=True)
daily_promo.rename(columns={'flow_times': '流水倍数'}, inplace=True)
daily_promo.rename(columns={'id': 'ID'}, inplace=True)
daily_promo.rename(columns={'issue_type': '问题类型'}, inplace=True)
daily_promo.rename(columns={'member_grade': '会员等级'}, inplace=True)
daily_promo.rename(columns={'member_id': '会员ID'}, inplace=True)
daily_promo.rename(columns={'member_name': '会员账号'}, inplace=True)

daily_promo.rename(columns={'money': '红利金额（元）'}, inplace=True)
daily_promo.rename(columns={'receive_mode': '接收模式'}, inplace=True)
daily_promo.rename(columns={'site_id': '申请站点'}, inplace=True)
daily_promo.rename(columns={'status': '状态'}, inplace=True)
daily_promo.rename(columns={'top_id': '上级代理ID'}, inplace=True)
daily_promo.rename(columns={'updated_at': '发放时间'}, inplace=True)
daily_promo.rename(columns={'venue_id': '场馆ID'}, inplace=True)
daily_promo.rename(columns={'wallet_category': '钱包类别'}, inplace=True)

# 指定列的顺序
column_order = ['申请站点', '订单号', '会员ID','会员账号', '上级代理ID',
                '会员等级', '钱包类别', '流水倍数', '红利金额（元）','申请时间',
                '发放时间', '操作人', '申请备注', '审核备注', '审核用户',
                '状态', '活动ID', '活动标题', '活动类型', '活动后金额',
                '活动前金额', '类别', '流水金额', '流水限额', 'ID',
                '问题类型', '接收模式', '场馆ID',
]

# 重新排列列的顺序
daily_promo = daily_promo[column_order]

daily_promo = daily_promo.drop(
        columns=['活动后金额', '活动前金额', '流水限额', '接收模式', '场馆ID', '上级代理ID', '活动类型', '类别', ])

# 输出数据到excel文件
daily_promo['申请站点'] = daily_promo['申请站点'].map({
    1000: "好博体育",
    2000: "黄金体育",
    3000: "宾利体育",
    4000: "HOME体育",
    5000: "亚洲之星",
    6000: "港岛体育",
    7000: "蓝火体育",
    8000: "A7体育",
    9000: "皇马体育",
    9001: "摩根体育",
    9002: "友博体育",
    9003: "跃动体育",
    9004: "港岛娱乐城",
    9005: "新完美体育",
    9010: "百羿娱乐",})

_out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'output'); os.makedirs(_out, exist_ok=True)
daily_promo.to_excel(os.path.join(_out, '红利单号_2.xlsx'), index=False)
