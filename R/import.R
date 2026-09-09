#' Harmonise two summary-statistics tables by allele alignment
#'
#' `harmonise_sumstats()` aligns the effect allele of `y` to that of `x` so
#' that effect sizes are directly comparable.  Matching is on `snp` when
#' available and on `chr:pos` otherwise.  Non-palindromic allele mismatches
#' are dropped; palindromic (A/T, C/G) variants are kept when the minor
#' allele frequency is informative (`maf <= max_maf_ambiguous`) and dropped
#' when it is not, mirroring common `TwoSampleMR` practice.
#'
#' @param x,y `pmr_sumstats` objects (or data.frames accepted by
#'   [import_sumstats()]).
#' @param max_maf_ambiguous Palindromic variants with MAF above this value are
#'   considered ambiguous and are dropped (default `0.42`).
#' @param maf_tol Tolerance for declaring palindromic MAF values concordant.
#' @param action One of `"drop_ambiguous"` (default) or `"keep_ambiguous"`.
#'
#' @return A list of class `pmr_harmonised` with elements `x`, `y`
#'   (harmonised, row-aligned), `dropped` (rows of `y` dropped), `report`
#'   (a named integer vector of counts), and `call`.
#' @export
#' @examples
#' x <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
#'                 beta = c(0.2, -0.1), se = c(0.03, 0.04),
#'                 p = c(1e-8, 1e-3), eaf = c(0.4, 0.6))
#' y <- data.frame(SNP = c("rs1", "rs2"), EA = c("G", "T"), OA = c("A", "C"),
#'                 BETA = c(0.25, 0.05), SE = c(0.03, 0.04),
#'                 P = c(1e-9, 0.01), EAF = c(0.6, 0.4))
#' h <- harmonise_sumstats(x, y)
#' h$report
harmonise_sumstats <- function(x, y, max_maf_ambiguous = 0.42,
                               maf_tol = 0.08,
                               action = c("drop_ambiguous", "keep_ambiguous")) {
  action <- match.arg(action)
  x <- .normalise_sumstats(x, need_coords = FALSE)
  y <- .normalise_sumstats(y, need_coords = FALSE)
  class(x) <- c("pmr_sumstats", "data.frame")
  class(y) <- c("pmr_sumstats", "data.frame")
  key_x <- if (!is.null(x$snp)) x$snp else paste(x$chr, x$pos, sep = ":")
  key_y <- if (!is.null(y$snp)) y$snp else paste(y$chr, y$pos, sep = ":")
  if (anyDuplicated(key_x) || anyDuplicated(key_y)) {
    warning("Duplicate identifiers in input; only first occurrence per key ",
            "is retained for harmonisation.", call. = FALSE)
  }
  kx <- !duplicated(key_x)
  ky <- !duplicated(key_y)
  m <- match(key_x[kx], key_y[ky])
  keep <- !is.na(m)
  ix <- which(kx)[keep]
  iy <- which(ky)[m[keep]]

  xa <- x$ea[ix]; xb <- x$oa[ix]
  ya <- y$ea[iy]; yb <- y$oa[iy]
  need_alleles <- is.na(xa) | is.na(xb) | is.na(ya) | is.na(yb)
  conc <- !need_alleles & .same_alleles(xa, ya) & .same_alleles(xb, yb)
  swap <- !need_alleles & .same_alleles(xa, yb) & .same_alleles(xb, ya)
  pal  <- !need_alleles & .is_palindromic(xa, xb) &
    .is_palindromic(ya, yb)
  flip <- swap

  amb <- rep(FALSE, length(ix))
  if (any(pal & !conc & !swap)) {
    maf_y <- pmin(y$eaf[iy], 1 - y$eaf[iy], na.rm = TRUE)
    inf  <- !is.na(maf_y) & maf_y <= max_maf_ambiguous
    close <- is.na(maf_y) | abs(maf_y - pmin(x$eaf[ix], 1 - x$eaf[ix],
                                             na.rm = TRUE)) <= maf_tol
    amb <- pal & !conc & !swap & !(inf & close)
  }

  usable <- !need_alleles & (conc | swap) & !amb
  if (action == "keep_ambiguous") usable <- usable | (pal & !conc & !swap & amb)
  if (any(pal & !conc & !swap & amb)) {
    warning(sum(pal & !conc & !swap & amb),
            " palindromic variant(s) with non-informative MAF ",
            if (action == "drop_ambiguous") "dropped" else "kept (unverified)",
            ".", call. = FALSE)
  }
  if (any(need_alleles)) {
    warning(sum(need_alleles),
            " matched variant(s) lacked allele information and were dropped.",
            call. = FALSE)
  }

  y_out <- y[iy[usable], , drop = FALSE]
  x_out <- x[ix[usable], , drop = FALSE]
  fl <- flip[usable]
  if (any(fl)) {
    y_out$beta <- -y_out$beta
    y_out$eaf <- 1 - y_out$eaf
    y_out$maf <- pmin(y_out$eaf, 1 - y_out$eaf, na.rm = TRUE)
  }

  dropped <- rbind(
    no_match = y[-iy, , drop = FALSE],
    mismatch = if (sum(!usable) > 0L) y[iy[!usable], , drop = FALSE]
  )
  report <- c(
    n_x = nrow(x), n_y = nrow(y), harmonised = sum(usable),
    allele_mismatch = sum(!need_alleles & !conc & !swap & !amb),
    palindromic_ambiguous = sum(pal & !conc & !swap & amb),
    missing_alleles = sum(need_alleles),
    no_common_key = sum(is.na(m))
  )
  out <- list(x = x_out, y = y_out, dropped = dropped, report = report,
              call = match.call())
  class(out) <- "pmr_harmonised"
  out
}
