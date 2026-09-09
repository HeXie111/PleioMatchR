#' Cross-ancestry allele-frequency drift check
#'
#' When the exposure and outcome GWAS come from different ancestral
#' populations (e.g. exposure in East Asians, outcome in Europeans), effect
#' alleles and allele frequencies may drift, and strand-ambiguous (palindromic)
#' variants become unreliable.  `cross_ancestry_check()` quantifies the
#' allele-frequency drift between two aligned summary-statistics tables and
#' flags variants at risk.  The module is **diagnostic only**: it does not
#' correct LD-tag flipping or effect sizes.
#'
#' Allele frequencies are expected to be frequencies of the effect allele
#' (`eaf`).  If the two tables use complementary effect alleles for the same
#' variant the frequency is automatically complemented (`1 - eaf`).
#'
#' @param x,y Data.frames of summary statistics with an `eaf` (or `maf`)
#'   column (see [import_sumstats()]).
#' @param label_x,label_y Ancestry/population labels for reporting.
#' @param drift_threshold Absolute allele-frequency difference above which a
#'   variant is flagged as drifting (default 0.05).
#' @param max_maf_ambiguous Palindromic variants with MAF above this value
#'   are flagged as strand-unreliable (default 0.42).
#' @param ... Reserved for future arguments.
#'
#' @return A `pmr_ancestry` list with `table` (per-variant drift and risk
#'   flags), `summary` (counts), `high_risk` (variants recommended for
#'   exclusion) and `verdict` (a human-readable text).
#' @export
#' @examples
#' a <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
#'                 eaf = c(0.45, 0.20), p = 1e-8)
#' b <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
#'                 eaf = c(0.42, 0.55), p = 0.2)
#' cross_ancestry_check(a, b, label_x = "EAS", label_y = "EUR")
cross_ancestry_check <- function(x, y, label_x = "population 1",
                                 label_y = "population 2",
                                 drift_threshold = 0.05,
                                 max_maf_ambiguous = 0.42, ...) {
  ax <- .ancestry_input(x)
  ay <- .ancestry_input(y)
  if (is.null(ax$eaf) || all(is.na(ax$eaf)) ||
      is.null(ay$eaf) || all(is.na(ay$eaf))) {
    stop("cross_ancestry_check() requires effect-allele frequency (`eaf`/",
         "`maf`) in both inputs.", call. = FALSE)
  }
  key <- ax$snp
  key_y <- ay$snp
  if (is.null(key)) stop("A SNP identifier column is required in both inputs.",
                         call. = FALSE)
  if (is.null(key_y)) stop("A SNP identifier column is required in both inputs.",
                           call. = FALSE)
  m <- match(key, key_y)
  keep <- !is.na(m)
  if (sum(keep) == 0L) stop("No overlapping variants between inputs.",
                            call. = FALSE)

  eaf_y <- ay$eaf[m[keep]]
  ea_y <- ay$ea[m[keep]]
  have_alleles <- !is.na(ax$ea[keep]) & !is.na(ax$oa[keep]) &
    !is.na(ea_y) & !is.na(ay$oa[m[keep]])
  swap <- have_alleles & .same_alleles(ax$ea[keep], ay$oa[m[keep]]) &
    .same_alleles(ax$oa[keep], ea_y)
  eaf_y[swap] <- 1 - eaf_y[swap]
  if (any(!have_alleles)) {
    warning(sum(!have_alleles),
            " variants lacked allele information; frequencies were compared ",
            "without allele alignment.", call. = FALSE)
  }

  daf <- abs(ax$eaf[keep] - eaf_y)
  pal <- .is_palindromic(ax$ea[keep], ax$oa[keep]) &
    .is_palindromic(ea_y, ay$oa[m[keep]])
  maf_max <- pmax(pmin(ax$eaf[keep], 1 - ax$eaf[keep]),
                  pmin(eaf_y, 1 - eaf_y), na.rm = TRUE)
  amb <- pal & (is.na(maf_max) | maf_max > max_maf_ambiguous)
  drift <- !is.na(daf) & daf >= drift_threshold

  tab <- data.frame(
    snp = key[keep],
    ea = ax$ea[keep], oa = ax$oa[keep],
    eaf_x = ax$eaf[keep], eaf_y = eaf_y,
    daf = daf,
    palindromic = pal,
    maf_max = maf_max,
    strand_unreliable = amb,
    high_drift = drift,
    high_risk = amb | drift,
    stringsAsFactors = FALSE)
  tab <- tab[order(tab$daf, decreasing = TRUE), , drop = FALSE]

  summary_tab <- data.frame(
    n_compared = nrow(tab),
    n_palindromic = sum(tab$palindromic, na.rm = TRUE),
    n_strand_unreliable = sum(tab$strand_unreliable, na.rm = TRUE),
    n_high_drift = sum(tab$high_drift, na.rm = TRUE),
    n_high_risk = sum(tab$high_risk, na.rm = TRUE),
    median_daf = stats::median(tab$daf, na.rm = TRUE),
    max_daf = max(tab$daf, na.rm = TRUE),
    stringsAsFactors = FALSE)
  high_risk <- tab[tab$high_risk, , drop = FALSE]
  verdict <- sprintf(paste0(
    "Cross-ancestry diagnostic (%s vs %s): %d/%d variants flagged. ",
    "%d strand-unreliable palindromic variants (MAF > %.2f) and %d variants ",
    "with |dAF| >= %.2f should be excluded or have strand verified before ",
    "direction testing."),
    label_x, label_y, summary_tab$n_high_risk, summary_tab$n_compared,
    summary_tab$n_strand_unreliable, max_maf_ambiguous,
    summary_tab$n_high_drift, drift_threshold)
  if (summary_tab$n_high_risk == 0L) {
    verdict <- sprintf(
      "Cross-ancestry diagnostic (%s vs %s): no high-risk variants. ",
      label_x, label_y)
  }
  out <- list(table = tab, summary = summary_tab, high_risk = high_risk,
              verdict = verdict, call = match.call())
  class(out) <- "pmr_ancestry"
  out
}

## Lenient canonical reader for ancestry checks (no coordinates required)
.ancestry_input <- function(x) {
  if (!is.data.frame(x)) {
    stop("Inputs must be data.frames.", call. = FALSE)
  }
  nms <- tolower(names(x))
  get <- function(kind) {
    h <- which(nms %in% .pleio_aliases[[kind]])
    if (length(h) == 0L) return(NULL)
    x[[h[1L]]]
  }
  ea <- toupper(as.character(get("ea") %||% NA_character_))
  oa <- toupper(as.character(get("oa") %||% NA_character_))
  eaf_raw <- get("eaf")
  eaf <- suppressWarnings(as.numeric(eaf_raw))
  if (is.null(eaf)) eaf <- suppressWarnings(as.numeric(get("maf")))
  list(snp = as.character(get("snp")),
       ea = ea, oa = oa, eaf = eaf)
}

#' @export
print.pmr_ancestry <- function(x, ...) {
  cat(x$verdict, "\n")
  if (nrow(x$high_risk) > 0L) {
    cat("Top risk variants:\n")
    print(utils::head(x$high_risk[, c("snp", "eaf_x", "eaf_y", "daf",
                                      "palindromic", "strand_unreliable")],
                      6L), row.names = FALSE)
  }
  invisible(x)
}
