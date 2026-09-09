#' Read a PLINK `--clump` output file
#'
#' Parses a `.clumped` file produced by PLINK 1.9 (`--clump`) into a tidy
#' data.frame.  Index variants and variants contained in the `SP2` column are
#' returned as separate rows so downstream enrichment counting treats one
#' clump as one independent signal when requested.
#'
#' @param file Path to a `.clumped` file.
#' @param ... Passed to [utils::read.table()].
#'
#' @return A data.frame with columns `chr`, `index_snp`, `bp`, `p`,
#'   `n_total` (`TOTAL`), `n_sig` (`NSIG`), `sp2_snps` (character vector of
#'   contained SNPs) and `n_sp2`.
#' @export
#' @examples
#' f <- system.file("extdata", "example.clumped", package = "PleioMatchR")
#' if (nzchar(f)) read_plink_clump(f)
read_plink_clump <- function(file, ...) {
  if (!file.exists(file)) stop("File not found: ", file, call. = FALSE)
  dat <- utils::read.table(file, header = TRUE, sep = "",
                           stringsAsFactors = FALSE, fill = TRUE,
                           comment.char = "", ...)
  names(dat) <- toupper(names(dat))
  have <- c("CHR", "SNP", "BP", "P")
  if (!all(have %in% names(dat))) {
    stop("Expected PLINK clump columns (CHR, SNP, BP, P, ...) not found in ",
         file, call. = FALSE)
  }
  sp2 <- if ("SP2" %in% names(dat)) dat$SP2 else rep(NA_character_, nrow(dat))
  sp2 <- gsub("\\([0-9]+\\)", "", sp2)
  sp2_list <- strsplit(sp2, ",")
  out <- data.frame(
    chr = dat$CHR, index_snp = dat$SNP, bp = dat$BP, p = dat$P,
    n_total = if ("TOTAL" %in% names(dat)) dat$TOTAL else NA_integer_,
    n_sig = if ("NSIG" %in% names(dat)) dat$NSIG else NA_integer_,
    stringsAsFactors = FALSE)
  out$n_sp2 <- lengths(sp2_list) - (is.na(sp2) | sp2 == "" | sp2 == "NONE")
  out$sp2_snps <- I(sp2_list)
  out
}

#' Greedy distance-based LD clumping
#'
#' A dependency-free proxy for LD clumping that keeps, per `kb` window, the
#' variant with the smallest p-value (or, if p is missing, the first variant
#' in input order).  For real data prefer PLINK `--clump` on a matched
#' reference panel; this function is intended for quick data cleaning and for
#' reproducible examples.
#'
#' @param snp Character vector of variant identifiers.
#' @param chr,pos Genomic coordinates.
#' @param p Optional p-values used for ranking (lower = higher priority).
#' @param kb Window size in kb (default 500).
#'
#' @return A data.frame with input columns plus `clump_id` (integer) and
#'   `keep` (logical: `TRUE` for the index variant of each clump).
#' @export
#' @examples
#' d <- data.frame(snp = paste0("s", 1:6), chr = 1,
#'                 pos = c(100, 200, 800, 1200, 4000, 4300),
#'                 p = c(0.5, 1e-8, 0.01, 0.9, 1e-6, 0.3))
#' clump_by_distance(d$snp, d$chr, d$pos, d$p, kb = 500)
clump_by_distance <- function(snp, chr, pos, p = NULL, kb = 500) {
  n <- length(snp)
  if (length(chr) != n || length(pos) != n) {
    stop("`snp`, `chr` and `pos` must have the same length.", call. = FALSE)
  }
  if (is.null(p)) {
    priority <- rep(NA_real_, n)
  } else {
    if (length(p) != n) stop("`p` must have the same length as `snp`.",
                             call. = FALSE)
    priority <- p
  }
  half <- as.numeric(kb) * 500
  clump_id <- integer(n)
  keep <- rep(FALSE, n)
  clump_counter <- 0L
  assigned <- rep(FALSE, n)
  ## Iterate in ascending p (or input order), then claim the window.
  prio_order <- order(priority, na.last = TRUE)
  for (i in prio_order) {
    if (assigned[i]) next
    clump_counter <- clump_counter + 1L
    in_clump <- chr == chr[i] & pos >= pos[i] - half & pos <= pos[i] + half
    in_clump <- in_clump & !assigned
    clump_id[in_clump] <- clump_counter
    assigned[in_clump] <- TRUE
    keep[i] <- TRUE
  }
  data.frame(snp = snp, chr = chr, pos = pos,
             p = if (is.null(p)) NA_real_ else p,
             clump_id = clump_id, keep = keep,
             stringsAsFactors = FALSE)
}
