# ------------------------------------------------------------------
# 修复：brms 随机效应提取，统一在一个函数里做类型转换
# 问题根源：dealer_effects 手动转了 as.integer(dealer_id)，但 ci995/ci999
# 是分别单独调用 ranef() 提取的，各自的 dealer_id 还停留在原始
# character/factor 状态，导致三个表两两合并时类型对不上。
# ------------------------------------------------------------------

extract_ranef_ci <- function(model, group_var, effect = "Intercept",
                              probs = c(0.025, 0.975), id_type = "integer") {
  raw <- ranef(model, probs = probs)[[group_var]][, , effect] |>
    as.data.table(keep.rownames = group_var)

  # 类型转换只在这一处发生——不管调用几次、传几套 probs，
  # 每次返回的 group_var 列类型都保证一致，后续 merge 不会再炸
  raw[[group_var]] <- switch(id_type,
    integer   = as.integer(raw[[group_var]]),
    character = as.character(raw[[group_var]]),
    raw[[group_var]]  # 其他类型原样返回，但会打印警告提醒手动检查
  )
  if (!id_type %in% c("integer", "character")) {
    warning(glue::glue("extract_ranef_ci: 未识别的id_type='{id_type}'，未做类型转换，请自行核对"))
  }
  raw
}

# ------------------------------------------------------------------
# 用法替换（原来手写三遍提取+手动转型，现在三次调用同一函数）
# ------------------------------------------------------------------
dealer_effects <- extract_ranef_ci(bayes_model, "dealer_id")
setnames(dealer_effects, c("dealer_id", "Estimate", "Est.Error", "Q2.5", "Q97.5"))

ci995 <- extract_ranef_ci(bayes_model, "dealer_id", probs = c(0.0025, 0.9975))
setnames(ci995, c("dealer_id", "Estimate", "Est.Error", "Q0.25", "Q99.75"))

ci999 <- extract_ranef_ci(bayes_model, "dealer_id", probs = c(0.0005, 0.9995))
setnames(ci999, c("dealer_id", "Estimate", "Est.Error", "Q0.05", "Q99.95"))

# 合并前再加一道防呆：任何一个表的 dealer_id 类型对不上，直接停下来报错，
# 而不是让 bmerge 用一句晦涩的英文报错把你拖回来排查
stopifnot(
  "dealer_id 类型不一致，检查 extract_ranef_ci 调用" =
    class(dealer_effects$dealer_id) == class(ci995$dealer_id) &&
    class(ci995$dealer_id) == class(ci999$dealer_id) &&
    class(ci999$dealer_id) == class(dealer_agg$dealer_id)
)

dealer_full_result <- merge(dealer_effects, dealer_agg, by = "dealer_id")
dealer_full_result <- merge(dealer_full_result, ci995[, .(dealer_id, Q0.25, Q99.75)], by = "dealer_id")
dealer_full_result <- merge(dealer_full_result, ci999[, .(dealer_id, Q0.05, Q99.95)], by = "dealer_id")
