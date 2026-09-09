.prs_flag <- function(x) {
  e <- x$enrichment
  d <- x$direction
  h <- x$heterogeneity
  n_dir <- d$n_directional
  wdc <- if (is.list(h) && !is.null(h$WDC)) h$WDC else NA_real_
  i2 <- if (is.list(h) && !is.null(h$I2)) h$I2 else NA_real_
  low_consistency <- n_dir >= 8L && (
    (!is.na(wdc) && abs(wdc) < 0.5) ||
      (!is.na(i2) && i2 > 50))
  if (is.na(e$enrichment_index) || e$p_upper > 0.05) {
    base <- "no significant enrichment; PRS construction not supported"
  } else if (low_consistency) {
    base <- "CAUTION: enrichment significant but direction consistency low; PRS may be diluted"
  } else {
    base <- "OK: enriched and directionally consistent"
  }
  base
}

#' Plot methods for `pmr_pleio` objects
#'
#' Three diagnostic plots are available:
#'
#' - `"null"`: histogram of the permutation null distribution of the
#'   enrichment index with the observed EI marked.
#' - `"forest"`: aligned per-locus outcome effects with 95% confidence
#'   intervals (hits filled, non-hits open).
#' - `"butterfly"` (default): two-panel diagnostic that combines enrichment
#'   (left) with per-locus direction (right) and prints a heuristic PRS
#'   suitability flag.
#'
#' @param x A `pmr_pleio` object.
#' @param which Which plot to draw.
#' @param ... Graphical parameters passed to the underlying plotting calls.
#'
#' @return Invisibly, `x`.
#' @export
#' @method plot pmr_pleio
#' @examples
#' data(demo_sentinels, package = "PleioMatchR")
#' data(demo_outcome, package = "PleioMatchR")
#' ctrl <- build_control_pool(demo_sentinels, demo_outcome, n_controls = 6,
#'                            seed = 42, verbose = FALSE)
#' res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
#'                   n_perm = 200, seed = 1, verbose = FALSE)
#' if (interactive()) plot(res, which = "null")
plot.pmr_pleio <- function(x, which = c("butterfly", "null", "forest"), ...) {
  which <- match.arg(which)
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par))
  if (which == "null") {
    .plot_null(x, ...)
  } else if (which == "forest") {
    .plot_forest(x, ...)
  } else {
    .plot_butterfly(x, ...)
  }
  invisible(x)
}

.plot_null <- function(x, ...) {
  ei <- x$enrichment$enrichment_index
  null <- x$permutation$null_ei
  null <- null[is.finite(null)]
  if (is.null(null) || length(null) < 2L) {
    plot.new()
    text(0.5, 0.5, "No permutation null available (n_perm = 0)", cex = 1.2)
    return(invisible(x))
  }
  graphics::hist(null, breaks = 40, col = "grey90", border = "grey60",
                 main = "Permutation null distribution of EI",
                 xlab = "Enrichment index under shared-control permutation",
                 ...)
  graphics::abline(v = ei, col = "tomato3", lwd = 2)
  graphics::mtext(sprintf("Observed EI = %s (p = %s)",
                          format(ei, digits = 3),
                          format(x$enrichment$p_upper, digits = 3)),
                  side = 3, col = "tomato3")
  invisible(x)
}

.plot_forest <- function(x, ...) {
  lt <- x$locus_table
  ok <- lt$direction_ok & !is.na(lt$aligned_beta) & !is.na(lt$aligned_se) &
    lt$aligned_se > 0
  if (sum(ok) == 0L) {
    plot.new()
    text(0.5, 0.5, "No directionally alignable loci", cex = 1.2)
    return(invisible(x))
  }
  lt <- lt[ok, , drop = FALSE]
  b <- lt$aligned_beta
  lo <- b - 1.96 * lt$aligned_se
  hi <- b + 1.96 * lt$aligned_se
  o <- order(b)
  b <- b[o]; lo <- lo[o]; hi <- hi[o]
  lab <- lt$sentinel_id[o]
  n <- length(b)
  y <- seq_len(n)
  xlim <- range(c(lo, hi), na.rm = TRUE)
  if (min(xlim) > 0) xlim[1L] <- 0
  if (max(xlim) < 0) xlim[2L] <- 0
  graphics::plot(0, type = "n", xlim = xlim, ylim = c(0.5, n + 0.5),
                 yaxt = "n", ylab = "", xlab = "Aligned outcome effect (beta)",
                 main = "Direction of outcome effects at sentinel loci")
  graphics::axis(2, at = y, labels = lab, las = 2, cex.axis = 0.7)
  graphics::abline(v = 0, lty = 2, col = "grey50")
  col <- ifelse(b > 0, "steelblue4", "tomato3")
  graphics::segments(lo, y, hi, y, col = col)
  graphics::points(b, y, pch = ifelse(lt$hit[o], 19, 1), col = col, cex = 1)
  invisible(x)
}

.plot_butterfly <- function(x, ...) {
  graphics::par(mfrow = c(1, 2))
  e <- x$enrichment
  ei <- e$enrichment_index
  graphics::barplot(c(ei, 1), names.arg = c("Observed", "Null"),
                    col = c("tomato3", "grey70"),
                    ylab = "Enrichment index",
                    main = "Association enrichment",
                    ylim = c(0, max(c(ei, 1.5), na.rm = TRUE) * 1.2))
  graphics::mtext(sprintf("EI = %s, p = %s (%d perms)",
                          ifelse(is.na(ei), "NA", format(ei, digits = 3)),
                          format(e$p_upper, digits = 3), e$n_perm),
                  side = 3, cex = 0.8)

  lt <- x$locus_table
  ok <- lt$direction_ok & !is.na(lt$aligned_beta) & !is.na(lt$aligned_se) &
    lt$aligned_se > 0
  z <- lt$aligned_beta[ok] / lt$aligned_se[ok]
  hits <- lt$hit[ok]
  graphics::plot(z, jitter(seq_along(z), amount = 0.25),
                 col = ifelse(z > 0, "steelblue4", "tomato3"),
                 pch = ifelse(hits, 19, 1), xlab = "Aligned z-score",
                 ylab = "Locus index",
                 main = "Directional consistency", yaxt = "n", ...)
  graphics::abline(v = 0, lty = 2, col = "grey50")
  d <- x$direction
  graphics::mtext(sprintf("%d positive / %d negative (p = %s)",
                          d$n_positive, d$n_negative,
                          format(d$binom_p, digits = 3)),
                  side = 3, cex = 0.8)
  graphics::mtext(.prs_flag(x), side = 1, line = 2.5, cex = 0.85,
                  col = if (grepl("CAUTION|not supported", .prs_flag(x)))
                    "tomato3" else "darkgreen")
  invisible(x)
}
