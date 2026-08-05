from sqlalchemy import create_engine
import re

engine = create_engine('mysql+pymysql://user:pwd@host:3306/ods_mariadb_2b')

# 正名规则函数，你自己改
def normalize_col(name):
    name = re.sub('([a-z0-9])([A-Z])', r'\1_\2', name) # 驼峰转下划线
    return name.lower().strip('_')

# 获取所有表
tables = engine.execute("SHOW TABLES").fetchall()

for (table,) in tables:
    cols = engine.execute(f"SHOW COLUMNS FROM {table}").fetchall()
    select_list = []
    for col in cols:
        old = col[0]
        new = normalize_col(old)
        if old!= new:
            select_list.append(f"`{old}` AS `{new}`")
        else:
            select_list.append(f"`{old}`")

    view_sql = f"CREATE OR REPLACE VIEW ods_mariadb_2b_std.{table} AS SELECT {', '.join(select_list)} FROM ods_mariadb_2b.{table};"
    print(view_sql)