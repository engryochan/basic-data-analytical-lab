# ==============================================================================
# loo_diagnostics_pipeline.R
# 大样本 brms 模型的 LOO 诊断——独立脚本，不在 Quarto 渲染进程里现算
#
# 核心原则：
#   1. 拟合(fit)和诊断(diagnose)是两件分开的事，各自独立跑、独立存档，
#      Quarto报告里只 readRDS() 读结果、不重新计算。
#   2. 全量10万行不做逐点PSIS-LOO（log_lik矩阵是 n_draws × n_obs，
#      10万列乘以几千次后验抽样，内存直接爆），改用loo_subsample()
#      做统计上有效的子抽样估计，而不是手动挑几个分层拍脑袋抽样。
#   3. moment_match只用在"精修问题点"，不当内存优化手段用；
#      ndraws只在log_lik/loo调用这一层临时生效，不动模型本体的
#      完整后验（模型精度和诊断计算成本分开控制）。
# ==============================================================================

library(brms)
library(loo)
library(data.table)

# ------------------------------------------------------------------
# 第一步：加载已经拟合好的模型（假设拟合脚本已单独跑完并存档）
# ------------------------------------------------------------------
bayes_model_cmdstan <- readRDS("models/bayes_model_cmdstan.rds")

# ------------------------------------------------------------------
# 第二步：定义一个"给定一批观测行，返回对应log-lik"的函数，
#         这是 loo_subsample() 要求的接口——它只在被抽中的行上
#         调用log_lik，不会碰全量10万行
# ------------------------------------------------------------------
llfun_subsample <- function(data_i, draws) {
  # data_i: 本次被抽中的那一小撮观测（loo_subsample内部按PPS抽样传入）
  # draws:  后验抽样对象（brms model本身）
  brms::log_lik(draws, newdata = data_i, ndraws = NULL)  # 用全部后验抽样，
  # 精度不打折——真正省内存的地方是"只对被抽中的行算"，不是"少用后验抽样"
}

# ------------------------------------------------------------------
# 第三步：跑 loo_subsample，指定子抽样观测数（比如2000行，
#         而不是全量10万行），得到带标准误的LOO估计
# ------------------------------------------------------------------
full_data <- bayes_model_cmdstan$data  # brms拟合时用的完整data.frame

loo_result_subsample <- loo_subsample(
  x           = llfun_subsample,
  draws       = bayes_model_cmdstan,
  data        = full_data,
  observations = 2000,     # 子抽样观测数，按内存预算调；不是"分层拍脑袋"，
                            # 是PPS抽样，自带理论依据
  cores       = parallel::detectCores() - 1
)

print(loo_result_subsample)
# 输出里会带 elpd_loo 的标准误——这是手动分层抽样给不了的关键信息，
# 报告里引用LOO数字时必须带这个标准误，否则读者无法判断这个子抽样
# 估计本身有多可信

# ------------------------------------------------------------------
# 第四步：对Pareto k值异常高的点（如果有），moment_match精修——
#         这一步是"提高精度"，会比第三步更耗资源，只对少数问题点做，
#         不是常规流程
# ------------------------------------------------------------------
bad_k_idx <- which(loo_result_subsample$diagnostics$pareto_k > 0.7)
if (length(bad_k_idx) > 0) {
  message(glue::glue("发现{length(bad_k_idx)}个Pareto k>0.7的问题点，做moment_match精修"))
  loo_result_subsample <- loo::loo_moment_match(
    bayes_model_cmdstan, loo_result_subsample,
    post_draws = brms::as_draws_array,
    log_lik_i  = brms:::log_lik_i.brmsfit  # 具体内部函数名以brms版本为准
  )
}

# ------------------------------------------------------------------
# 第五步：存档，Quarto报告里只readRDS()这个文件
# ------------------------------------------------------------------
saveRDS(loo_result_subsample, "models/loo_result_subsample.rds")

# ------------------------------------------------------------------
# 附：不同模型结构对比时的注意事项——
#   两个模型的LOO/ELPD只有在"同一批被抽中的观测行"上算出来的才能直接
#   相减比较（loo::loo_compare()要求）。用loo_subsample时，两个候选
#   模型务必用相同的随机种子/相同的observations抽样方案，否则
#   loo_compare()给出的差值没有意义。
# ------------------------------------------------------------------
