#' Weighted direction consistency and effect-size heterogeneity
#'
#' Quantifies, for a vector of outcome effect estimates (one per locus,
#' already aligned to a common effect allele), two complementary summaries of
#' directional consistency:
#'
#' - **WDC** (weighted direction consistency): the precision-weighted mean of
#'   `sign(beta)`.  Under randomly oriented effects WDC is centred on 0; under
#'   perfectly consistent orientation it approaches +1 or -1.  Its empirical
#'   null distribution is obtained by sign-flipping each effect (conditional
#'   on `se`, which is preserved under the sign flip).
#' - **I2 / Q**: Cochran's Q, DerSimonian-Laird tau-squared and the I2
#'   heterogeneity percentage from the random-effects meta-analysis of the
#'   aligned effects.  High I2 indicates that per-locus effects point in
#'   directions that cannot be pooled into a single cross-trait effect.
#'
#' These statistics are descriptive diagnostics; before being used as formal
#' tests in a methods paper they should be calibrated by simulation (see the
#' package vignette for a worked type-I-error example).
#'
#' @param beta Numeric vector of aligned effect sizes.
#' @param se Numeric vector of standard errors (same length as `beta`,
#'   strictly positive).
#' @param method One of `"both"`, `"I2"` or `"WDC"`.
#' @param n_perm Number of sign-flip permutations for the WDC null
#'   distribution (default 9999).
#' @param seed Random seed for WDC permutation.
#' @param ... Reserved for future arguments.
#'
#' @return A list with `n`, `WDC`, `wdc_p` (two-sided sign-flip p-value),
#'   `Q`, `Q_df`, `Q_p`, `tau2`, `I2`, and `note` about the descriptive
#'   nature of these statistics.
#' @export
#' @examples
#' set.seed(1)
#' direction_heterogeneity(rnorm(20, 0.05, 0.05), rep(0.02, 20), n_perm = 999)
direction_heterogeneity <- function(beta, se,
                                    method = c("both", "I2", "WDC"),
                                    n_perm = 9999L, seed = NULL, ...) {
  method <- match.arg(method)
  if (length(beta) != length(se)) {
    stop("`beta` and `se` must have the same length.", call. = FALSE)
  }
  ok <- !is.na(beta) & !is.na(se) & se > 0
  if (sum(ok) < 2L) {
    stop("At least two non-missing effects with positive SE are required.",
         call. = FALSE)
  }
  beta <- beta[ok]; se <- se[ok]
  n <- length(beta)
  w <- 1 / se^2
  yw <- stats::weighted.mean(beta, w)
  Q <- sum(w * (beta - yw)^2)
  df <- n - 1
  C <- sum(w) - sum(w^2) / sum(w)
  tau2 <- if (Q > df && C > 0) (Q - df) / C else 0
  I2 <- if (Q > 0) max(0, (Q - df) / Q) * 100 else 0
  Q_p <- stats::pchisq(Q, df, lower.tail = FALSE)

  wdc <- NA_real_
  wdc_p <- NA_real_
  if (method %in% c("both", "WDC")) {
    sgn <- ifelse(beta > 0, 1, ifelse(beta < 0, -1, 0))
    wdc <- sum(w * sgn) / sum(w)
    B <- as.integer(n_perm)
    if (!is.null(seed)) set.seed(seed)
    if (B > 0L) {
      S <- matrix(sample(c(-1, 0, 1), B * n, replace = TRUE,
                         prob = c(0.5, 0, 0.5)), nrow = B, ncol = n)
      wdc_null <- rowSums(S * rep(w, each = B)) / sum(w)
      wdc_p <- mean(abs(wdc_null) >= abs(wdc))
    }
  }
  out <- list(
    n = n,
    mean_effect = yw,
    WDC = wdc,
    wdc_p = wdc_p,
    Q = Q, Q_df = df, Q_p = Q_p,
    tau2 = tau2, I2 = I2,
    note = paste0("Descriptive statistics; WDC/I2 thresholds should be ",
                  "calibrated by simulation before use as formal tests."),
    call = match.call()
  )
  if (method == "I2") out$WDC <- out$wdc_p <- NULL
  if (method == "WDC") out[c("Q", "Q_df", "Q_p", "tau2", "I2")] <- NULL
  out
}
