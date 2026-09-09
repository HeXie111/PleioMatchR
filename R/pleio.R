#' Pleiotropy enrichment and direction test
#'
#' `pleio_test()` answers, for a predefined set of exposure loci ("sentinels"),
#' whether these loci are enriched for association with an outcome trait and
#' whether their outcome effect directions are consistent or random.
#'
#' **Enrichment.** A sentinel is a "hit" when the outcome GWAS contains at
#' least one variant with `p <= p_threshold` inside a `+/- window_kb` window.
#' Matched control variants (see [build_control_pool()]) receive identical
#' windows and thresholds.  The enrichment index (EI) is
#' `observed_hits / expected_hits`, where the expected count is the sum of
#' within-matched-set means (the exact null expectation of the paired
#' permutation).  An empirical p-value is obtained by randomly assigning the
#' "case" label within each sentinel-control matched set across `n_perm`
#' permutations.  This shared-control paired permutation keeps the exchange
#' unit at the level of the matched set and therefore accounts for the
#' non-independence that arises because one control variant can be matched to
#' several sentinels.
#'
#' **Direction.** For every sentinel, the lead outcome variant in the window
#' is aligned to the exposure effect allele (allele swaps flip the sign;
#' palindromic variants with MAF > 0.42 are excluded).  A two-sided exact
#' binomial test evaluates whether the proportion of positive aligned effects
#' deviates from 0.5, i.e. whether directions are more consistent (or more
#' antagonistic) than random.
#'
#' @param sentinel Data.frame of exposure index variants (see
#'   [import_sumstats()] for accepted columns).  Effect alleles are optional
#'   but recommended for direction alignment.
#' @param outcome Data.frame of outcome GWAS summary statistics.
#' @param controls A `pmr_controls` object from [build_control_pool()], or
#'   `NULL` to build controls on the fly from `outcome` (default matching
#'   parameters can be changed through `control_args`).
#' @param p_threshold Outcome p-value threshold defining a hit
#'   (default `5e-8`).
#' @param window_kb Half-width (kb) of the sentinel window used for
#'   hit calling and lead-variant extraction (default 500).
#' @param n_perm Number of shared-control paired permutations (default 10000).
#' @param direction_on Whether the direction test uses all sentinels with an
#'   alignable lead variant (`"all"`, default) or only sentinels whose window
#'   contains an outcome hit (`"hits"`).
#' @param control_args Optional list of arguments passed to
#'   [build_control_pool()] when `controls = NULL`.
#' @param seed Random seed; `NULL` leaves the RNG state untouched.
#' @param verbose Print a one-line summary.
#' @param ... Reserved for future arguments.
#'
#' @return An object of class `pmr_pleio` containing `enrichment`
#'   (EI, expected/observed hits, empirical p-value and permutation CI),
#'   `direction` (test summary), `locus_table` (per-sentinel detail),
#'   `heterogeneity` (experimental weighted direction diagnostics from
#'   [direction_heterogeneity()]), `permutation` (null EI vector),
#'   `sets` (per-sentinel matched-set hit values), `controls` and `call`.
#' @export
#' @seealso [build_control_pool()] [direction_heterogeneity()]
#'   [stratify_by_pathway()] [plot.pmr_pleio()]
#' @examples
#' data(demo_sentinels, package = "PleioMatchR")
#' data(demo_outcome, package = "PleioMatchR")
#' ctrl <- build_control_pool(demo_sentinels, demo_outcome,
#'                            n_controls = 8, seed = 42, verbose = FALSE)
#' res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
#'                   n_perm = 500, seed = 1)
#' res
pleio_test <- function(sentinel, outcome, controls = NULL,
                       p_threshold = 5e-8, window_kb = 500,
                       n_perm = 10000L,
                       direction_on = c("all", "hits"),
                       control_args = list(), seed = NULL,
                       verbose = TRUE, ...) {
  direction_on <- match.arg(direction_on)
  sent <- .as_sentinels(sentinel)
  out <- .as_sentinels(outcome)
  .req_chr_pos(sent, "pleio_test()")
  .req_chr_pos(out, "pleio_test()")
  if (is.null(out$p) || all(is.na(out$p))) {
    stop("pleio_test() requires outcome p-values.", call. = FALSE)
  }
  if (is.null(sent$p) || all(is.na(sent$p))) {
    warning("No exposure p-values provided; sentinel status is taken as given.",
            call. = FALSE)
  }
  window <- as.numeric(window_kb) * 1000
  B <- as.integer(n_perm)
  if (!is.null(seed)) set.seed(seed)

  ## ----- Controls ----------------------------------------------------------
  if (is.null(controls)) {
    ca <- modifyList(list(sentinel = sent, pool = out, verbose = FALSE),
                     control_args)
    controls <- do.call(build_control_pool, ca)
  }
  if (!inherits(controls, "pmr_controls")) {
    if (is.data.frame(controls) &&
        all(c("sentinel_id", "chr", "pos") %in% names(controls))) {
      tmp <- list(sentinel = sent, controls = controls,
                  diagnostics = list(balance = NULL, notes = character()))
      class(tmp) <- "pmr_controls"
      controls <- tmp
    } else {
      stop("`controls` must be a `pmr_controls` object or a data.frame with ",
           "`sentinel_id`, `chr` and `pos` columns.", call. = FALSE)
    }
  }
  ctrl <- controls$controls
  if (nrow(ctrl) == 0L) stop("Control table is empty.", call. = FALSE)

  ## ----- Hit calling -------------------------------------------------------
  ws <- .window_scan(sent$chr, sent$pos, out, window, p_threshold)
  ws_ctrl <- .window_scan(ctrl$chr, ctrl$pos, out, window, p_threshold)
  hit_case <- ws$hit
  hit_ctrl <- ws_ctrl$hit

  m <- nrow(sent)
  set_vals <- lapply(seq_len(m), function(i) {
    k <- which(ctrl$sentinel_id == sent$snp[i])
    c(hit_case[i], hit_ctrl[k])
  })
  E0 <- sum(vapply(set_vals, mean, numeric(1)))
  T_obs <- sum(hit_case)

  if (E0 > 0) {
    EI_obs <- T_obs / E0
  } else {
    EI_obs <- NA_real_
  }

  T_null <- NULL
  ei_null <- NULL
  p_upper <- NA_real_
  p_two <- NA_real_
  if (B > 0L) {
    X <- matrix(NA_real_, nrow = B, ncol = m)
    for (i in seq_len(m)) {
      v <- set_vals[[i]]
      X[, i] <- if (length(v) == 1L) rep(v, B) else sample(v, B, replace = TRUE)
    }
    T_null <- rowSums(X)
    if (E0 > 0) ei_null <- T_null / E0
    p_upper <- mean(T_null >= T_obs)
    p_two <- mean(abs(T_null - E0) >= abs(T_obs - E0))
  }
  mc_se <- if (!is.na(p_upper)) sqrt(p_upper * (1 - p_upper) / B) else NA_real_

  obs_rate <- mean(hit_case)
  exp_rate <- if (m > 0) E0 / m else NA_real_
  ctrl_rate <- mean(hit_ctrl)
  ci <- if (!is.null(ei_null) && length(ei_null) > 0L) {
    stats::quantile(ei_null, probs = c(0.025, 0.975), names = FALSE)
  } else c(NA_real_, NA_real_)
  enrichment <- data.frame(
    sentinels = m, hits_observed = T_obs,
    hits_expected = E0, hit_rate_observed = obs_rate,
    hit_rate_expected = exp_rate, control_hit_rate = ctrl_rate,
    enrichment_index = EI_obs, ei_null_low = ci[1L], ei_null_high = ci[2L],
    p_upper = p_upper, p_twosided = p_two,
    p_mc_se = mc_se, n_perm = B,
    p_threshold = p_threshold, window_kb = window_kb,
    stringsAsFactors = FALSE)

  ## ----- Per-locus lead variant and direction alignment ---------------------
  ld <- .direction_table(sent, out, ws, window)

  dir_keep <- ld$direction_ok & !is.na(ld$aligned_beta)
  if (direction_on == "hits") dir_keep <- dir_keep & ld$hit
  beta_v <- ld$aligned_beta[dir_keep]
  se_v <- ld$aligned_se[dir_keep]
  n_dir <- length(beta_v)
  if (n_dir >= 1L) {
    pos <- sum(beta_v > 0, na.rm = TRUE)
    neg <- sum(beta_v < 0, na.rm = TRUE)
    zero <- sum(beta_v == 0, na.rm = TRUE)
    bt <- stats::binom.test(pos, pos + neg, p = 0.5)
    direction_test <- data.frame(
      n_directional = pos + neg, n_positive = pos, n_negative = neg,
      n_zero = zero, prop_positive = pos / max(1, pos + neg),
      prop_consistent_positive = pos / max(1, n_dir),
      binom_p = bt$p.value,
      method = "two-sided exact binomial on aligned effect signs",
      stringsAsFactors = FALSE)
  } else {
    direction_test <- data.frame(
      n_directional = 0L, n_positive = NA_integer_, n_negative = NA_integer_,
      n_zero = NA_integer_, prop_positive = NA_real_,
      prop_consistent_positive = NA_real_, binom_p = NA_real_,
      method = "no alignable effects",
      stringsAsFactors = FALSE)
  }

  het <- if (n_dir >= 3L) {
    direction_heterogeneity(beta_v, se_v, n_perm = min(B, 9999L), seed = seed)
  } else list(n = n_dir, note = "fewer than 3 effects; heterogeneity not estimated")

  out_obj <- list(
    enrichment = enrichment,
    direction = direction_test,
    heterogeneity = het,
    locus_table = ld,
    permutation = list(null_ei = ei_null, null_total = T_null),
    sets = set_vals,
    controls = controls,
    call = match.call()
  )
  class(out_obj) <- "pmr_pleio"
  if (verbose) {
    cat(sprintf(paste0("Enrichment: EI = %s (p = %s, %d perms); ",
                       "direction: %d/%d positive (p = %s)\n"),
                ifelse(is.na(EI_obs), "NA", format(EI_obs, digits = 3)),
                format(p_upper, digits = 3), B,
                direction_test$n_positive, direction_test$n_directional,
                format(direction_test$binom_p, digits = 3)))
  }
  out_obj
}

## Internal: per-sentinel lead variant + allele alignment --------------------
.direction_table <- function(sent, out, ws, window) {
  m <- nrow(sent)
  lead_idx <- ws$index
  ld <- data.frame(
    sentinel_id = sent$snp, sentinel_chr = sent$chr, sentinel_pos = sent$pos,
    sentinel_beta = if (is.null(sent$beta)) NA_real_ else sent$beta,
    hit = ws$hit, window_p = ws$p,
    lead_snp = NA_character_, lead_pos = NA_integer_,
    lead_p = NA_real_, lead_beta = NA_real_, lead_se = NA_real_,
    aligned_beta = NA_real_, aligned_se = NA_real_,
    direction_ok = FALSE, direction_note = NA_character_,
    palindrome = FALSE, same_direction = NA,
    stringsAsFactors = FALSE)
  for (i in seq_len(m)) {
    idx <- lead_idx[i]
    if (idx == 0L) {
      ld$direction_note[i] <- "no outcome variant inside window"
      next
    }
    r <- out[idx, , drop = FALSE]
    ld$lead_snp[i] <- r$snp
    ld$lead_pos[i] <- r$pos
    ld$lead_p[i] <- r$p
    ld$lead_beta[i] <- r$beta
    ld$lead_se[i] <- r$se
    ld$palindrome[i] <- .is_palindromic(sent$ea[i], sent$oa[i]) ||
      .is_palindromic(r$ea, r$oa)

    if (is.na(sent$ea[i]) || is.na(sent$oa[i]) ||
        is.na(r$ea) || is.na(r$oa)) {
      ld$direction_note[i] <- "alleles unavailable for alignment"
      next
    }
    same <- .same_alleles(sent$ea[i], r$ea) & .same_alleles(sent$oa[i], r$oa)
    swap <- .same_alleles(sent$ea[i], r$oa) & .same_alleles(sent$oa[i], r$ea)
    if (same) {
      mult <- 1
      ld$direction_ok[i] <- TRUE
    } else if (swap) {
      mult <- -1
      ld$direction_ok[i] <- TRUE
    } else if (.is_palindromic(sent$ea[i], sent$oa[i])) {
      maf_r <- r$maf
      if (is.na(maf_r) || maf_r > 0.42) {
        ld$direction_note[i] <- paste0(
          "palindromic variant with non-informative MAF (",
          ifelse(is.na(maf_r), "MAF missing", format(maf_r, digits = 2)),
          "); strand orientation ambiguous")
        next
      }
      mult <- 1
      ld$direction_ok[i] <- TRUE
      ld$direction_note[i] <- "palindromic variant aligned by MAF (assumed strand-concordant)"
    } else {
      ld$direction_note[i] <- "non-palindromic allele mismatch after alignment attempt"
      next
    }
    ld$aligned_beta[i] <- mult * r$beta
    ld$aligned_se[i] <- r$se
    if (!is.na(ld$sentinel_beta[i]) && !is.na(r$beta) &&
        ld$sentinel_beta[i] != 0 && r$beta != 0) {
      ld$same_direction[i] <- sign(ld$sentinel_beta[i]) == sign(mult * r$beta)
    }
  }
  ld
}

#' @export
print.pmr_pleio <- function(x, ...) {
  e <- x$enrichment
  d <- x$direction
  cat("PleioMatchR pleiotropy diagnostic\n")
  cat("--------------------------------\n")
  cat(sprintf(paste0("Enrichment  : EI = %s (%d observed / %s expected hits); ",
                     "empirical p = %s (%s one-sided)\n"),
              ifelse(is.na(e$enrichment_index), "NA",
                     format(e$enrichment_index, digits = 3)),
              e$hits_observed, format(e$hits_expected, digits = 3),
              format(e$p_upper, digits = 3),
              ifelse(is.na(e$p_mc_se), "NA",
                     paste0("MC SE ", format(e$p_mc_se, digits = 3)))))
  cat(sprintf(paste0("Direction   : %s positive / %s directional; ",
                     "binomial p = %s\n"),
              d$n_positive, d$n_directional, format(d$binom_p, digits = 3)))
  if (is.list(x$heterogeneity) && !is.null(x$heterogeneity$I2)) {
    cat(sprintf("Heterogeneity: WDC = %s, I2 = %s%%, Q p = %s (experimental)\n",
                format(x$heterogeneity$WDC, digits = 3),
                format(x$heterogeneity$I2, digits = 3),
                format(x$heterogeneity$Q_p, digits = 3)))
  }
  invisible(x)
}

#' @export
summary.pmr_pleio <- function(object, ...) {
  list(
    enrichment = object$enrichment,
    direction = object$direction,
    heterogeneity = object$heterogeneity,
    locus_table = object$locus_table
  )
}
