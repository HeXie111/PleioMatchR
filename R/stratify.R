#' Pathway-stratified pleiotropy diagnostics
#'
#' Re-runs the enrichment and direction diagnostics of a [pleio_test()]
#' result within user-defined subgroups of sentinel loci (for example
#' "obesity axis" versus "islet axis" loci defined through nearby-gene
#' annotation).  A global signal that looks directionally random can hide two
#' internally consistent subgroups with opposite directions; stratification
#' makes that structure explicit.
#'
#' @param x A `pmr_pleio` object from [pleio_test()].
#' @param annotation Either a named character vector (`snp = pathway`) or a
#'   data.frame with SNP and pathway columns.  Sentinels absent from the
#'   annotation are reported and excluded.
#' @param min_loci Minimum number of sentinel loci required to report a
#'   stratum (default 2).
#' @param n_perm Permutations for the per-stratum enrichment p-value
#'   (default 1000).
#' @param seed Random seed.
#' @param ... Reserved for future arguments.
#'
#' @return A `pmr_stratified` object: a list with `results` (one row per
#'   pathway), `global` (the input global diagnostics), and `warnings`.
#' @export
#' @examples
#' data(demo_sentinels, package = "PleioMatchR")
#' data(demo_outcome, package = "PleioMatchR")
#' ctrl <- build_control_pool(demo_sentinels, demo_outcome, n_controls = 6,
#'                            seed = 42, verbose = FALSE)
#' res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
#'                   n_perm = 200, seed = 1, verbose = FALSE)
#' annot <- data.frame(snp = demo_sentinels$snp,
#'                     pathway = demo_sentinels$pathway)
#' stratify_by_pathway(res, annot, n_perm = 100, seed = 1)
stratify_by_pathway <- function(x, annotation, min_loci = 2L,
                                n_perm = 1000L, seed = NULL, ...) {
  if (!inherits(x, "pmr_pleio")) {
    stop("`x` must be a `pmr_pleio` object from pleio_test().", call. = FALSE)
  }
  if (is.character(annotation) && !is.null(names(annotation))) {
    annotation <- data.frame(snp = names(annotation),
                             pathway = unname(annotation),
                             stringsAsFactors = FALSE)
  }
  if (!is.data.frame(annotation) ||
      !all(c("snp", "pathway") %in% names(annotation))) {
    stop("`annotation` must be a named vector or data.frame with `snp` and ",
         "`pathway` columns.", call. = FALSE)
  }
  annotation <- annotation[!is.na(annotation$pathway), , drop = FALSE]
  if (nrow(annotation) == 0L) stop("Annotation contains no valid rows.",
                                   call. = FALSE)
  lt <- x$locus_table
  ann <- annotation[annotation$snp %in% lt$sentinel_id, , drop = FALSE]
  missing <- setdiff(annotation$snp, lt$sentinel_id)
  if (length(missing) > 0L) {
    warning(length(missing), " annotated SNP(s) not found in `x`: ",
            paste(head(missing, 5), collapse = ", "), call. = FALSE)
  }
  if (nrow(ann) == 0L) {
    stop("No annotated SNP matches the sentinels in `x`.", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  path_levels <- unique(ann$pathway)
  rows <- vector("list", length(path_levels))
  for (j in seq_along(path_levels)) {
    gp <- path_levels[j]
    ids <- ann$snp[ann$pathway == gp]
    sub <- lt[lt$sentinel_id %in% ids, , drop = FALSE]
    n_loc <- nrow(sub)
    if (n_loc < min_loci) {
      rows[[j]] <- data.frame(
        pathway = gp, n_loci = n_loc,
        enrichment_index = NA_real_, p_upper = NA_real_,
        n_directional = 0L, n_positive = NA_integer_,
        prop_positive = NA_real_, binom_p = NA_real_,
        WDC = NA_real_, I2 = NA_real_, Q_p = NA_real_,
        stringsAsFactors = FALSE)
      next
    }
    set_pos <- match(ids, lt$sentinel_id)
    set_pos <- set_pos[!is.na(set_pos)]
    sets <- x$sets[set_pos]
    T_obs <- sum(vapply(sets, function(z) z[1L], numeric(1)))
    E0 <- sum(vapply(sets, mean, numeric(1)))
    EI <- if (E0 > 0) T_obs / E0 else NA_real_
    p_up <- NA_real_
    if (!is.null(sets) && length(sets) > 0L && E0 > 0 && n_perm > 0) {
      X <- matrix(NA_real_, nrow = n_perm, ncol = length(sets))
      for (k in seq_along(sets)) {
        v <- sets[[k]]
        X[, k] <- if (length(v) == 1L) rep(v, n_perm) else
          sample(v, n_perm, replace = TRUE)
      }
      p_up <- mean(rowSums(X) >= T_obs)
    }

    dir <- sub$direction_ok & !is.na(sub$aligned_beta)
    beta_v <- sub$aligned_beta[dir]
    se_v <- sub$aligned_se[dir]
    if (length(beta_v) >= 1L) {
      npos <- sum(beta_v > 0)
      bt <- stats::binom.test(npos, length(beta_v), p = 0.5)
    } else {
      npos <- NA_integer_
      bt <- list(p.value = NA_real_)
    }
    het <- if (length(beta_v) >= 3L) {
      direction_heterogeneity(beta_v, se_v, n_perm = 999L, seed = seed)
    } else list(WDC = NA_real_, I2 = NA_real_, Q_p = NA_real_)
    rows[[j]] <- data.frame(
      pathway = gp, n_loci = n_loc,
      n_hits = sum(sub$hit),
      enrichment_index = EI, p_upper = p_up,
      n_directional = length(beta_v),
      n_positive = npos,
      prop_positive = if (length(beta_v) > 0) npos / length(beta_v) else NA_real_,
      binom_p = unname(bt$p.value),
      WDC = unname(het$WDC), I2 = unname(het$I2), Q_p = unname(het$Q_p),
      stringsAsFactors = FALSE)
  }
  out <- list(
    results = do.call(rbind, rows),
    global = list(enrichment = x$enrichment, direction = x$direction),
    warnings = c(missing = length(missing),
                 strata_below_min = sum(vapply(rows, function(r)
                   is.na(r$enrichment_index[1L]) && r$n_loci[1L] > 0L,
                   logical(1)))),
    call = match.call()
  )
  rownames(out$results) <- NULL
  class(out) <- "pmr_stratified"
  out
}

#' @export
print.pmr_stratified <- function(x, ...) {
  cat("Pathway-stratified pleiotropy diagnostics\n")
  r <- x$results
  r_disp <- r
  num_cols <- c("enrichment_index", "p_upper", "prop_positive", "binom_p",
                "WDC", "I2", "Q_p")
  for (cc in num_cols) {
    r_disp[[cc]] <- formatC(r[[cc]], digits = 3, format = "fg",
                            flag = "#", width = -1)
  }
  r_disp$n_hits <- NULL
  print(r_disp, row.names = FALSE)
  invisible(x)
}
