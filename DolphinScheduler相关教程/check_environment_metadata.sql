-- ============================================================
-- check_environment_metadata.sql
--
-- 目标：不再靠 DolphinScheduler Admin 网页上被截断的"环境配置"列去猜，
-- 直接从 DolphinScheduler 自己的元数据库里把完整文本和 Worker分组绑定
-- 关系拉出来。
--
-- 注意：这是 DolphinScheduler 自身的后台元数据库（存工作流定义/环境/
-- 用户这些），跟你平时用 Superset 连的 StarRocks 生产数据库是两个完全
-- 不同的库——DS 官方默认支持 MySQL 或 PostgreSQL 作为元数据存储，具体
-- 是哪个、库名叫什么，需要你自己确认（一般在 DS 安装目录的
-- conf/application.yaml 或 install_env.sh 里能看到连接串）。
-- 你需要能直接连上这个库才能跑下面的 SQL，跟 Superset SQL Lab 是分开
-- 的两条访问路径。
-- ============================================================


-- ---------- 第一步：不猜表名，先自动发现 ----------
-- MySQL 版本：
SELECT table_name
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND (table_name LIKE '%environment%' OR table_name LIKE '%worker_group%')
ORDER BY table_name;

-- PostgreSQL 版本（如果你的 DS 元数据库是 PG，把上面那条换成这个）：
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND (table_name ILIKE '%environment%' OR table_name ILIKE '%worker_group%')
-- ORDER BY table_name;


-- ---------- 第二步：环境完整配置文本（不再被 UI 截断） ----------
-- 大概率是 t_ds_environment 这张表，字段名对照官方 API 定义应该是
-- code / name / config / description。如果第一步发现表名不一样，
-- 把下面的表名换成第一步查到的真实结果即可。
SELECT
    code,
    name,
    config          AS full_config_text,
    description,
    create_time,
    update_time
FROM t_ds_environment
ORDER BY name;


-- ---------- 第三步：环境 <-> Worker分组 绑定关系 ----------
-- 表名按 t_ds_relation_project_worker_group 的命名规律推断，
-- 如果第一步查出来的真实表名不同，同样替换掉即可。
SELECT
    e.name              AS environment_name,
    e.code              AS environment_code,
    r.worker_group,
    r.create_time       AS binding_create_time
FROM t_ds_environment e
LEFT JOIN t_ds_relation_environment_worker_group r
       ON r.environment_code = e.code
ORDER BY e.name;
-- 如果某个环境在这里查出来完全没有匹配行（LEFT JOIN 后 worker_group
-- 是 NULL），就实锤了：这个环境目前没有绑定任何 Worker 分组，
-- 对应 UI 列表页上那一列的空白。


-- ---------- 第四步（可选）：反过来看，某个 Worker 分组绑了哪些环境 ----------
SELECT
    r.worker_group,
    e.name AS environment_name,
    e.code AS environment_code
FROM t_ds_relation_environment_worker_group r
JOIN t_ds_environment e ON e.code = r.environment_code
WHERE r.worker_group = 'default'   -- 换成你要核对的分组名
ORDER BY e.name;
