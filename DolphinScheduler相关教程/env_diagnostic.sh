#!/usr/bin/env bash
# env_diagnostic.sh
#
# 用法：上传到 DolphinScheduler「资源中心」，在要检查的环境所在的任意
# SHELL 任务节点里，「环境名称」下拉框选中目标环境，命令框里写一行：
#   bash env_diagnostic.sh
# （资源中心的文件会被自动下载到任务执行目录，跟之前
#  ryochan_sparklyr_submit.sh 走的是同一套"资源本地化"机制）
#
# 一次只能检查一个环境——DolphinScheduler 的任务节点一次只绑定一个
# 环境，想核对 demo / wm-business-risk-prod / PROD Risk Livy-Spark /
# PROD Risk SeaTunnel ODS 这四个，就是同一个节点切着环境名称跑四次，
# 或者建四个节点各绑一个。

set -uo pipefail

echo "===== 环境变量 (env | sort) ====="
env | sort

echo
echo "===== 关键变量逐个核对（密码类只报字符数，不回显明文） ====="
for var in LIVY_HOST LIVY_PORT LIVY_USER LIVY_PASSWORD SPARK_HOME JAVA_HOME \
           HADOOP_CONF_DIR SPARKLYR_CONNECT_METHOD SPARKLYR_MASTER \
           SPARKLYR_EXTRA_JARS SPARK_EVENT_LOG_S3 TZ PATH; do
  if [[ -v "$var" ]]; then
    value="${!var}"
    if [[ "$var" == *PASSWORD* || "$var" == *SECRET* || "$var" == *TOKEN* ]]; then
      printf '%s=<已设置，%d 个字符，不回显内容>\n' "$var" "${#value}"
    else
      printf '%s=%s\n' "$var" "$value"
    fi
  else
    printf '%s=<未设置>\n' "$var"
  fi
done

echo
echo "===== 关键命令是否在 PATH 上 ====="
for cmd in spark-submit Rscript python3 aws hdfs curl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '%-14s -> %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf '%-14s -> 未找到\n' "$cmd"
  fi
done

echo
echo "===== 当前 worker 主机信息（帮你对照 Worker分组是不是分派对了机器）====="
printf 'hostname=%s\n' "$(hostname -f 2>/dev/null || hostname)"
printf 'whoami=%s\n' "$(whoami)"
printf 'pwd=%s\n' "$(pwd)"
