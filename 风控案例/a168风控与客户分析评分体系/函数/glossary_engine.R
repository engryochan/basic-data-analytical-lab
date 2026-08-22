# =====================================================================
# glossary_engine.R · a168 统一术语字典引擎与悬停浮层
# ---------------------------------------------------------------------
# 引擎版本 : 1.0.0     适配字典 : 1.0.0     日期 : 2026-08-18
# 配套     : 规范/glossary_a168_v1.0.0.yaml（单一真相源）
#            规范/glossary_a168_v1.0.0.csv （派生字典，UTF-8-BOM）
# 身份     : 数据资产（配置件），从属于三份权威主件；★ 不构成第四份权威文件
# ---------------------------------------------------------------------
# 【血统】浮层定位逻辑移植自 a168风控与客户分层评分体系_商业方案.qmd 之 place()
#         （body 级单一 fixed 浮层、四向夹紧、不用 ::after 伪元素——后者会被
#          祖先容器 overflow:hidden 与表格滚动区裁掉）。本引擎在其上补五项：
#          ① 表格／滚动容器几何感知（择向用，夹紧域仍取视口）
#          ② 滚动时重定位（母本为直接隐藏，宽表横拖体验受损）
#          ③ 触屏 touchstart（四档与两主件此前皆缺，手机端完全看不到释义）
#          ④ 键盘 focus/blur + ARIA（读屏可达）
#          ⑤ 八字段结构化渲染（母本为两段式纯文本）
#
# 【在 qmd 中如何用】
#   source("函数/glossary_engine.R")
#   GL <- glossary_load()                 # 默认路径已按项目布局
#   cat(glossary_assets(GL))              # 注入 CSS + JS（一次即可）
#   # 正文：`r gtip("hold%")`  或  `r gtip("hold%", "抽水率")`
#   knitr::kable(glossary_table(GL))      # 字典总表
#   glossary_conflicts(GL)                # 同名异义台账
# =====================================================================

suppressPackageStartupMessages(library(data.table))
## v1.5.0 斧正：去单机绝对路径（换机即断），改相对路径；术语库驻 规范/（五命名空间归化）。
## 工作目录 = qmd 所在目录；如需兜底可 options(registry.root = "<项目根>")。
path <- { .r <- getOption("registry.root", ""); if (nzchar(.r)) paste0(sub("/+$", "", .r), "/") else "" }
.gstage <- function(tag, expr) tryCatch(expr, error = function(e)
  stop(sprintf("【glossary·%s】%s", tag, conditionMessage(e)), call. = FALSE))

GLOSSARY_PATHS <- list(
  yaml = file.path(paste0(path, "规范/", "glossary_a168_v1.0.0.yaml")),
  csv  = file.path(paste0(path, "规范/", "glossary_a168_v1.0.0.csv"))
)

glossary_sixtuple <- function(path) {
  raw  <- readBin(path, "raw", n = file.size(path))
  crlf <- if (length(raw) > 1L)
            any(raw[-length(raw)] == as.raw(13L) & raw[-1L] == as.raw(10L)) else FALSE
  bom  <- length(raw) >= 3L && identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))
  data.table(文件名 = basename(path), 总行数按LF计 = sum(raw == as.raw(10L)),
             字节数 = length(raw), MD5 = unname(tools::md5sum(path)),
             换行符 = if (crlf) "CRLF" else "LF", BOM = if (bom) "有" else "无")
}

glossary_load <- function(yaml_path = GLOSSARY_PATHS$yaml,
                          csv_path  = GLOSSARY_PATHS$csv) {
  .gstage("G00 文件门", {
    absent <- c(yaml_path, csv_path)[!file.exists(c(yaml_path, csv_path))]
    if (length(absent))
      stop(sprintf("○ 待表：当前工作目录\n  %s\n之下未找到：%s\n（铁律第九条：不以静态文字冒充结果）",
                   getwd(), paste(absent, collapse = "、")))
  })

  dict <- .gstage("G01 CSV载入", {
    d <- fread(csv_path, encoding = "UTF-8")
    need <- c("术语","类别","定义","用途","计算状态","实施状态","同名异义","schema")
    miss <- setdiff(need, names(d))
    if (length(miss)) stop(sprintf("CSV 缺列：%s", paste(miss, collapse = "、")))
    d[, 同名异义 := toupper(trimws(同名异义)) == "TRUE"]
    if (anyDuplicated(d$术语)) stop("CSV 中术语不唯一——字典主键必须唯一")
    d[]
  })

  meta <- NULL; mode <- "CSV-ONLY"
  if (requireNamespace("yaml", quietly = TRUE)) {
    meta <- .gstage("G02 YAML载入", yaml::read_yaml(yaml_path)); mode <- "YAML+CSV"
  } else {
    warning("【glossary】未装 yaml 包，降级纯 CSV 模式；交叉一致性断言未执行。")
  }

  if (!is.null(meta)) .gstage("G03 YAML↔CSV 交叉比对", {
    y <- vapply(meta$terms, function(t) t$term, character(1))
    if (!setequal(y, dict$术语))
      stop(sprintf("术语集合不一致——仅YAML：%s；仅CSV：%s",
                   paste(head(setdiff(y, dict$术语), 5), collapse = "、"),
                   paste(head(setdiff(dict$术语, y), 5), collapse = "、")))
    if (!identical(as.character(meta$glossary$version), "1.0.0"))
      stop(sprintf("YAML version=%s，引擎预期 1.0.0——请同步递增",
                   meta$glossary$version))
  })

  structure(list(dict = dict, meta = meta, mode = mode,
                 identity = rbind(glossary_sixtuple(yaml_path), glossary_sixtuple(csv_path)),
                 loaded_at = Sys.time()), class = "a168_glossary")
}

# ---------------------------------------------------------------------
# 八字段结构化释义文本（供 data-tip 承载；纯文本，段以 ¦ 分隔，由 JS 还原）
# ---------------------------------------------------------------------
.g_plain <- function(x) {
  x <- gsub("\\*\\*|`|\\$", "", as.character(x))
  gsub("[[:space:]]+", " ", trimws(x))
}
.g_body <- function(r) {
  seg <- c(sprintf("【定义】%s", .g_plain(r$定义)),
           sprintf("【用途】%s", .g_plain(r$用途)))
  cal <- paste(na.omit(c(
    if (nzchar(r$口径_分子))   sprintf("分子：%s", .g_plain(r$口径_分子)),
    if (nzchar(r$口径_分母))   sprintf("分母：%s", .g_plain(r$口径_分母)),
    if (nzchar(r$口径_粒度))   sprintf("粒度：%s", .g_plain(r$口径_粒度)),
    if (nzchar(r$口径_时间窗)) sprintf("时间窗：%s", .g_plain(r$口径_时间窗)),
    if (nzchar(r$口径_数据源)) sprintf("数据源：%s", .g_plain(r$口径_数据源)))),
    collapse = " ｜ ")
  if (nzchar(cal))              seg <- c(seg, sprintf("【口径】%s", cal))
  if (nzchar(r$指标与阈值))     seg <- c(seg, sprintf("【指标与阈值】%s", .g_plain(r$指标与阈值)))
  ob <- paste(na.omit(c(
    if (nzchar(r$越界后果_高于)) sprintf("高于：%s", .g_plain(r$越界后果_高于)),
    if (nzchar(r$越界后果_低于)) sprintf("低于：%s", .g_plain(r$越界后果_低于)))),
    collapse = " ｜ ")
  if (nzchar(ob))               seg <- c(seg, sprintf("【越界后果】%s", ob))
  if (nzchar(r$替代与升级))     seg <- c(seg, sprintf("【替代与升级】%s", .g_plain(r$替代与升级)))
  seg <- c(seg, sprintf("【状态】计算：%s ｜ 实施：%s", r$计算状态, r$实施状态))
  if (nzchar(r$口径状态) && r$口径状态 != "（待补）")
    seg <- c(seg, sprintf("【口径状态】%s", .g_plain(r$口径状态)))
  if (isTRUE(r$同名异义) && nzchar(r$冲突登记))
    seg <- c(seg, sprintf("【同名异义】%s", .g_plain(r$冲突登记)))
  paste(seg, collapse = " ¦ ")
}

.g_esc <- function(x) gsub('"', "&quot;", gsub("<", "&lt;", gsub(">", "&gt;", x)))

## 正文写 `r gtip("hold%")`；术语不在字典则原样返回并静默计数
gtip <- function(k, show = NULL, GL = get0(".GL_ACTIVE", envir = globalenv())) {
  lbl <- if (is.null(show)) k else show
  if (is.null(GL)) return(lbl)
  r <- GL$dict[术语 == k]
  if (!nrow(r)) return(lbl)
  sprintf('<span class="gl-tip" tabindex="0" role="button" aria-label="%s 释义" data-tip="%s">%s</span>',
          .g_esc(k), .g_esc(.g_body(as.list(r[1L]))), lbl)
}

glossary_activate <- function(GL) { assign(".GL_ACTIVE", GL, envir = globalenv()); invisible(GL) }

# ---------------------------------------------------------------------
# 资产注入：CSS + JS（母本 place() 升级版）
# ---------------------------------------------------------------------
glossary_assets <- function(GL) {
paste0('
<style>
.gl-tip{border-bottom:1px dotted var(--ac,#22d3ee);cursor:help;}
.gl-tip:focus{outline:2px solid var(--ac,#22d3ee);outline-offset:2px;}
#gl-pop{position:fixed;z-index:2147483647;display:none;
  max-width:min(46rem,calc(100vw - 2rem));max-height:60vh;overflow-y:auto;
  padding:.7rem .9rem;border-radius:8px;font-size:.86rem;line-height:1.6;
  text-align:left;white-space:normal;word-break:break-word;overflow-wrap:anywhere;
  background:linear-gradient(135deg,rgba(8,36,60,.985),rgba(11,61,58,.985));
  color:#e7fbf3;border:1px solid rgba(34,211,238,.55);
  box-shadow:0 12px 36px rgba(0,0,0,.6);pointer-events:none;}
#gl-pop .gl-h{color:#7dd3fc;font-weight:600;}
#gl-pop .gl-s{display:block;margin:.15rem 0;}
</style>
<div id="gl-pop" role="tooltip" aria-live="polite"></div>
<script>
(function(){
  function ready(fn){
    if(document.readyState==="loading"){document.addEventListener("DOMContentLoaded",fn);}else{fn();}
    window.addEventListener("load",function(){try{fn();}catch(e){}});
  }
  ready(function(){
    var pop=document.getElementById("gl-pop"); if(!pop)return;
    var cur=null;
    /* 八字段渲染：¦ 分段，【…】作小标题 */
    function render(txt){
      pop.innerHTML="";
      txt.split(" ¦ ").forEach(function(s){
        var d=document.createElement("span"); d.className="gl-s";
        var m=s.match(/^【([^】]+)】([\\s\\S]*)$/);
        if(m){var b=document.createElement("span");b.className="gl-h";b.textContent="【"+m[1]+"】";
              d.appendChild(b); d.appendChild(document.createTextNode(m[2]));}
        else{d.textContent=s;}
        pop.appendChild(d);
      });
    }
    /* ★ 表格／滚动容器几何感知：仅用于择向，夹紧域仍取视口——
       若把浮层夹进表格边界，宽表滚动区常仅数百像素，八字段会被压成极窄长条。 */
    function scrollBox(el){
      for(var p=el.parentElement;p;p=p.parentElement){
        var st=getComputedStyle(p);
        if(/(auto|scroll)/.test(st.overflowX+st.overflowY)) return p;
      }
      return null;
    }
    function place(t){
      render(t.getAttribute("data-tip")||"");
      pop.style.display="block"; pop.style.left="0px"; pop.style.top="0px";
      var r=t.getBoundingClientRect(), w=pop.offsetWidth, h=pop.offsetHeight, M=10;
      var box=scrollBox(t), br=box?box.getBoundingClientRect():null;
      /* 择向：以容器（有则用之，否则用视口）判断上下左右哪侧余量大 */
      var topRoom   =(br?Math.max(r.top-br.top,r.top):r.top);
      var botRoom   =(br?Math.max(br.bottom-r.bottom,window.innerHeight-r.bottom)
                        :window.innerHeight-r.bottom);
      var y=(botRoom>=h+M||botRoom>=topRoom)? r.bottom+6 : r.top-h-6;
      var x=r.left;
      if(br&&(br.left+br.right)/2>window.innerWidth/2&&x+w>window.innerWidth-M) x=r.right-w;
      /* 夹紧域＝视口（四向），容器一律不夹 */
      if(x+w>window.innerWidth-M) x=window.innerWidth-w-M;
      if(x<M) x=M;
      if(y+h>window.innerHeight-M) y=window.innerHeight-h-M;
      if(y<M) y=M;
      pop.style.left=x+"px"; pop.style.top=y+"px"; cur=t;
    }
    function hide(){pop.style.display="none"; cur=null;}
    function isTip(t){return t&&t.classList&&t.classList.contains("gl-tip");}
    document.body.addEventListener("mouseover",function(e){if(isTip(e.target))place(e.target);},true);
    document.body.addEventListener("mouseout", function(e){if(isTip(e.target))hide();},true);
    document.body.addEventListener("focusin",  function(e){if(isTip(e.target))place(e.target);},true);
    document.body.addEventListener("focusout", function(e){if(isTip(e.target))hide();},true);
    /* 触屏：轻触切换，点别处关闭 */
    document.body.addEventListener("touchstart",function(e){
      var t=e.target.closest?e.target.closest(".gl-tip"):null;
      if(t){ if(cur===t){hide();}else{place(t);} e.preventDefault(); } else { hide(); }
    },{passive:false});
    document.addEventListener("keydown",function(e){if(e.key==="Escape")hide();});
    /* ★ 滚动重定位（母本为直接隐藏）：表格横拖时浮层跟随而非漂移或消失 */
    var tick=false;
    window.addEventListener("scroll",function(){
      if(!cur||tick)return; tick=true;
      requestAnimationFrame(function(){ if(cur)place(cur); tick=false; });
    },true);
    window.addEventListener("resize",function(){ if(cur)place(cur); });
  });
})();
</script>
')
}

# ---------------------------------------------------------------------
# 呈表助手
# ---------------------------------------------------------------------
glossary_table <- function(GL, category = NULL, full8_only = FALSE) {
  d <- copy(GL$dict)
  if (!is.null(category)) d <- d[类别 %chin% category]
  if (full8_only) d <- d[schema == "FULL8"]
  out <- d[, .(术语, 类别, 定义 = substr(定义, 1, 90), 用途 = substr(用途, 1, 70),
               计算状态, 实施状态,
               同名异义 = fifelse(同名异义, "⚠", "—"), 出现档数 = lengths(strsplit(出现档, "；")))]
  setorder(out, 类别, 术语); out[]
}

glossary_conflicts <- function(GL) {
  d <- GL$dict[同名异义 == TRUE]
  out <- d[, .(术语, 类别, 冲突登记, 出现档, 权威取自, 已出八字段 = fifelse(schema == "FULL8", "✅", "—"))]
  setorder(out, -已出八字段, 术语); out[]
}

glossary_pending <- function(GL) {
  d <- GL$dict[schema == "MIN"]
  d[, .(术语, 类别, 出现档数 = lengths(strsplit(出现档, "；")), 权威取自)][order(-出现档数, 术语)]
}

print.a168_glossary <- function(x, ...) {
  d <- x$dict
  cat(sprintf("a168 统一术语字典 · 模式=%s · 载入于 %s\n", x$mode,
              format(x$loaded_at, "%Y-%m-%d %H:%M:%S")))
  cat(sprintf("  术语 %d 条 · 八字段完备 %d 条 · 同名异义 %d 条 · 跨档共现 %d 条\n",
              nrow(d), sum(d$schema == "FULL8"), sum(d$同名异义),
              sum(lengths(strsplit(d$出现档, "；")) > 1)))
  cat(sprintf("  类别 %d 种；待补八字段 %d 条（见 glossary_pending()）\n",
              uniqueN(d$类别), sum(d$schema == "MIN")))
  invisible(x)
}
