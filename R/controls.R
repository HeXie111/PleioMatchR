#' Build a matched control pool for pleiotropy enrichment testing
#'
#' For each sentinel locus (index variant of an exposure trait),
#' `build_control_pool()` samples a set of matched "null" variants from a
#' reference pool (usually the outcome GWAS) that are used as the control arm
#' of the enrichment test.  Matching implements the genome-aware criteria
#' used for pleiotropy diagnostics: same chromosome, minor-allele-frequency
#' (MAF) tolerance, physical distance from the sentinel larger than
#' `min_dist`, and exclusion of variants reaching outcome genome-wide
#' significance (so controls are not contaminated by the outcome signal).
#'
#' When `ld_scores` are supplied, variants are additionally stratified by
#' within-chromosome LD-score quantiles and controls are required to fall in
#' the same stratum as the sentinel.  This makes the case and control variant
#' sets comparable in local LD density (a proxy for genomic background
#' polygenicity), which is not possible with generic causal-inference matching
#' packages such as `MatchIt`.
#'
#' @param sentinel Data.frame of exposure index variants.  Columns accepted
#'   by [import_sumstats()] plus an optional exposure `beta`.
#' @param pool Data.frame of variants from which controls are sampled
#'   (typically the outcome GWAS).  Should not be restricted to significant
#'   variants.
#' @param n_controls Number of controls per sentinel (default 10).
#' @param maf_tol Absolute MAF tolerance for matching (default 0.03).
#' @param min_dist Minimum physical distance (bp) between a sentinel and its
#'   controls (default 5e5, i.e. 500 kb).
#' @param exclude_p Outcome p-value threshold below which pool variants are
#'   excluded from serving as controls (default 5e-8).  Set to `NULL` to
#'   disable.
#' @param ld_scores Optional data.frame with a SNP identifier column and an
#'   LD-score column (any of the aliases used by [import_sumstats()] plus
#'   `ldscore`/`score`/`l2`), enabling LD-score stratified matching.
#' @param ldscore_strata Number of LD-score quantile strata per chromosome
#'   (default 5).
#' @param seed Random seed for reproducible sampling.
#' @param verbose Print a short matching summary.
#' @param ... Reserved for future arguments.
#'
#' @return A `pmr_controls` object: a list with `sentinel` (canonical sentinel
#'   table), `controls` (one row per matched variant, including `sentinel_id`,
#'   `pool_index`, `dist_sentinel`, `maf_diff`, `ldscore_diff` and `stratum`),
#'   `diagnostics` (per-sentinel coverage and balance tables plus notes) and
#'   `call`.
#' @export
#' @examples
#' set.seed(1)
#' sent <- data.frame(snp = paste0("rs", 1:5), chr = 1, pos = seq(1e6, 9e6, 2e6),
#'                    ea = "A", oa = "G", eaf = runif(5, 0.2, 0.8),
#'                    beta = rnorm(5), se = 0.05, p = 1e-10)
#' pool <- data.frame(snp = paste0("g", 1:5000), chr = 1,
#'                    pos = seq(1e4, 1e8, length.out = 5000),
#'                    ea = sample(c("A", "C"), 5000, TRUE),
#'                    oa = sample(c("G", "T"), 5000, TRUE),
#'                    eaf = runif(5000), beta = rnorm(5000), se = 0.05,
#'                    p = runif(5000))
#' ctrl <- build_control_pool(sent, pool, n_controls = 8, seed = 42)
#' ctrl
build_control_pool <- function(sentinel, pool, n_controls = 10L,
                               maf_tol = 0.03, min_dist = 5e5,
                               exclude_p = 5e-8, ld_scores = NULL,
                               ldscore_strata = 5L, seed = 1L,
                               verbose = TRUE, ...) {
  sent <- .as_sentinels(sentinel)
  pl <- .as_sentinels(pool)
  .req_chr_pos(sent, "build_control_pool()")
  .req_chr_pos(pl, "build_control_pool()")
  .req_maf(sent, "build_control_pool()")
  if (is.null(pl$maf) || all(is.na(pl$maf))) {
    stop("build_control_pool() requires allele frequency in `pool`.",
         call. = FALSE)
  }
  n_controls <- as.integer(n_controls)
  if (n_controls < 1L) stop("`n_controls` must be >= 1.", call. = FALSE)
  if (!is.null(seed)) set.seed(seed)

  notes <- character()
  ld_present <- !is.null(ld_scores)
  strata_vec <- NULL
  sent_stratum <- NULL
  if (ld_present) {
    if (!is.data.frame(ld_scores)) {
      stop("`ld_scores` must be a data.frame.", call. = FALSE)
    }
    sc_col <- tolower(names(ld_scores))
    snp_col <- sc_col %in% .pleio_aliases$snp
    if (!any(snp_col)) {
      stop("`ld_scores` must contain a SNP identifier column (e.g. `snp` or ",
           "`rsid`).", call. = FALSE)
    }
    sc_idx <- which(sc_col %in% c("ldscore", "ld_score", "score", "l2",
                                  "snp_ldscore"))
    sc_col <- sc_col[sc_idx]
    if (length(sc_col) == 0L) {
      stop("`ld_scores` must contain an LD-score column named e.g. ",
           "`ldscore`, `score` or `l2`.", call. = FALSE)
    }
    ld_key <- as.character(ld_scores[[which(snp_col)[1L]]])
    ld_score <- suppressWarnings(as.numeric(
      ld_scores[[sc_idx[1L]]]))
    if (anyNA(ld_score)) {
      stop("`ld_scores` contains missing LD scores.", call. = FALSE)
    }
    p_key <- if (!is.null(pl$snp)) pl$snp else paste(pl$chr, pl$pos, sep = ":")
    m_pl <- match(p_key, ld_key)
    if (mean(!is.na(m_pl)) < 0.8) {
      warning("Fewer than 80% of pool variants matched to `ld_scores`.",
              call. = FALSE)
    }
    pl$ldscore <- ld_score[m_pl]
    s_key <- if (!is.null(sent$snp)) sent$snp else paste(sent$chr, sent$pos,
                                                         sep = ":")
    m_s <- match(s_key, ld_key)
    sent$ldscore <- ld_score[m_s]
    if (all(is.na(sent$ldscore))) {
      warning("No sentinel matched to `ld_scores`; LD-score matching disabled.",
              call. = FALSE)
      ld_present <- FALSE
    }
  }

  if (ld_present) {
    br <- function(z, n_breaks = ldscore_strata) {
      qs <- stats::quantile(z, probs = seq(0, 1, length.out = n_breaks + 1),
                            na.rm = TRUE, names = FALSE)
      qs <- unique(qs)
      as.integer(cut(z, breaks = qs, include.lowest = TRUE, labels = FALSE))
    }
    lds_by_chr <- split(pl$ldscore, pl$chr)
    strata_by_chr <- lapply(lds_by_chr, br)
    pl$stratum <- unsplit(strata_by_chr,
                          factor(pl$chr, levels = unique(pl$chr)))
    sent$stratum <- vapply(seq_len(nrow(sent)), function(i) {
      z <- lds_by_chr[[as.character(sent$chr[i])]]
      if (is.null(z) || is.na(sent$ldscore[i])) return(NA_integer_)
      sum(sent$ldscore[i] > stats::quantile(z, seq(0, 1,
        length.out = ldscore_strata + 1), names = FALSE, na.rm = TRUE)) + 1L
    }, integer(1))
    sent$stratum[sent$stratum > ldscore_strata] <- ldscore_strata
    n_miss_strat <- sum(is.na(sent$stratum))
    if (n_miss_strat > 0L) {
      notes <- c(notes, paste0(
        n_miss_strat, " sentinel(s) without LD score: stratum constraint ",
        "not applied to them."))
    }
  } else {
    pl$stratum <- NA_integer_
    sent$stratum <- NA_integer_
  }

  ## Pre-split pool by chromosome for fast matching
  chr_split <- split(seq_len(nrow(pl)), factor(pl$chr,
                                                levels = unique(pl$chr)))
  sent_order <- order(sent$chr, sent$pos)
  ctrl_rows <- vector("list", nrow(sent))
  per_sent <- vector("list", nrow(sent))
  for (ii in seq_len(nrow(sent))) {
    i <- sent_order[ii]
    cc <- sent$chr[i]
    cand <- chr_split[[as.character(cc)]]
    if (is.null(cand)) {
      ctrl_rows[[i]] <- integer()
      per_sent[[i]] <- data.frame(
        sentinel_id = sent$snp[i], chr = cc, pos = sent$pos[i],
        n_matched = 0L, n_candidates = 0L,
        mean_abs_maf_diff = NA_real_, mean_abs_ldscore_diff = NA_real_,
        stringsAsFactors = FALSE)
      next
    }
    dist_ok <- abs(pl$pos[cand] - sent$pos[i]) > min_dist
    maf_ok <- abs(pl$maf[cand] - sent$maf[i]) <= maf_tol
    keep <- dist_ok & maf_ok
    if (!is.null(exclude_p)) {
      keep <- keep & (is.na(pl$p[cand]) | pl$p[cand] >= exclude_p)
    }
    if (ld_present && !is.na(sent$stratum[i])) {
      keep <- keep & pl$stratum[cand] == sent$stratum[i]
    }
    idx <- cand[keep]
    n_avail <- length(idx)
    if (n_avail == 0L) {
      ctrl_rows[[i]] <- integer()
      per_sent[[i]] <- data.frame(
        sentinel_id = sent$snp[i], chr = cc, pos = sent$pos[i],
        n_matched = 0L, n_candidates = 0L,
        mean_abs_maf_diff = NA_real_, mean_abs_ldscore_diff = NA_real_,
        stringsAsFactors = FALSE)
      next
    }
    take <- if (n_avail > n_controls) {
      sample(idx, n_controls)
    } else if (n_avail == n_controls) {
      idx
    } else {
      notes <- c(notes, paste0("Sentinel ", sent$snp[i], ": only ", n_avail,
                               " eligible control(s) for ", n_controls,
                               " requested."))
      idx
    }
    ctrl_rows[[i]] <- take
    per_sent[[i]] <- data.frame(
      sentinel_id = sent$snp[i], chr = cc, pos = sent$pos[i],
      n_matched = length(take), n_candidates = n_avail,
      mean_abs_maf_diff = mean(abs(pl$maf[take] - sent$maf[i])),
      mean_abs_ldscore_diff = if (ld_present) {
        mean(abs(pl$ldscore[take] - sent$ldscore[i]), na.rm = TRUE)
      } else NA_real_,
      stringsAsFactors = FALSE)
  }
  per_sent <- do.call(rbind, per_sent)
  rownames(per_sent) <- NULL

  keep_ctrl <- unlist(ctrl_rows, use.names = FALSE)
  if (length(keep_ctrl) == 0L) {
    stop("No control variant could be matched. Relax `maf_tol`, `min_dist`, ",
         "`exclude_p`, or check that `pool` covers the sentinel chromosomes.",
         call. = FALSE)
  }
  set_id <- rep(sent$snp, vapply(ctrl_rows, length, integer(1)))
  ctrl_df <- pl[keep_ctrl, , drop = FALSE]
  ctrl_df$sentinel_id <- set_id
  sent_idx <- match(ctrl_df$sentinel_id, sent$snp)
  ctrl_df$dist_sentinel <- abs(ctrl_df$pos - sent$pos[sent_idx])
  ctrl_df$maf_diff <- ctrl_df$maf - sent$maf[sent_idx]
  ctrl_df$ldscore_diff <- if (ld_present) {
    ctrl_df$ldscore - sent$ldscore[sent_idx]
  } else NA_real_
  ctrl_df$stratum <- ctrl_df$stratum
  rownames(ctrl_df) <- NULL

  n_shared <- if (ld_present || TRUE) {
    tab <- table(ctrl_df$snp[!is.na(ctrl_df$snp)])
    if (length(tab) == 0L) 0 else max(tab)
  } else 0
  reuse_tab <- table(ctrl_df$snp[!is.na(ctrl_df$snp)])
  mean_reuse <- if (length(reuse_tab) == 0L) NA_real_ else
    mean(as.numeric(reuse_tab))
  diagnostics <- list(
    per_sentinel = per_sent,
    n_controls = n_controls,
    maf_tol = maf_tol,
    min_dist = min_dist,
    exclude_p = exclude_p,
    ld_stratified = ld_present,
    n_ld_strata = if (ld_present) ldscore_strata else NA_integer_,
    max_control_reuse = n_shared,
    mean_control_reuse = mean_reuse,
    balance = c(
      mean_abs_maf_diff = mean(abs(ctrl_df$maf_diff), na.rm = TRUE),
      mean_maf_diff = mean(ctrl_df$maf_diff, na.rm = TRUE),
      mean_abs_ldscore_diff = mean(abs(ctrl_df$ldscore_diff), na.rm = TRUE),
      n_matched = nrow(ctrl_df),
      coverage = mean(per_sent$n_matched >= n_controls)
    ),
    notes = unique(notes)
  )
  if (verbose) {
    cat(sprintf(paste0("Matched %d controls for %d sentinels ",
                       "(median %d per sentinel).\n"),
                nrow(ctrl_df), nrow(sent), stats::median(per_sent$n_matched)))
    if (ld_present) cat("LD-score stratified matching: ON\n")
  }
  out <- list(sentinel = sent, controls = ctrl_df,
              diagnostics = diagnostics, call = match.call())
  class(out) <- "pmr_controls"
  out
}

#' @export
print.pmr_controls <- function(x, ...) {
  cat("Matched control pool for ", nrow(x$sentinel), " sentinel(s)\n", sep = "")
  cat("  controls matched: ", nrow(x$controls), "\n", sep = "")
  cat("  mean |MAF diff|:  ",
      format(x$diagnostics$balance["mean_abs_maf_diff"], digits = 3), "\n",
      sep = "")
  cat("  LD-score strata:  ",
      if (x$diagnostics$ld_stratified)
        paste0("ON (", x$diagnostics$n_ld_strata, " strata)")
      else "OFF", "\n", sep = "")
  cat("  coverage (>= n requested): ",
      format(x$diagnostics$balance["coverage"] * 100, digits = 3), "%\n",
      sep = "")
  if (length(x$diagnostics$notes) > 0L) {
    cat("  notes:\n")
    for (n in x$diagnostics$notes) cat("    - ", n, "\n", sep = "")
  }
  invisible(x)
}

#' @export
summary.pmr_controls <- function(object, ...) {
  out <- object$diagnostics$per_sentinel
  class(out) <- c("summary.pmr_controls", "data.frame")
  out
}
