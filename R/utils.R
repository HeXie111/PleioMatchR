## Internal utilities -------------------------------------------------------

.pleio_aliases <- list(
  snp = c("snp", "rsid", "rs_id", "marker", "markername", "marker_id",
          "snpid", "variant_id", "id", "rs"),
  chr = c("chr", "chrom", "chromosome"),
  pos = c("pos", "position", "bp", "basepair", "base_pair", "hg19pos",
          "hg38pos"),
  ea  = c("ea", "effect_allele", "effectallele", "a1", "allele1", "alt",
          "effect", "minor_allele", "min_allele"),
  oa  = c("oa", "other_allele", "otherallele", "a2", "allele2", "ref",
          "reference", "non_effect_allele", "effect_other_allele"),
  beta = c("beta", "effect_size", "effectsize", "effect", "b", "est",
           "coefficient", "log_or", "logor"),
  se  = c("se", "std_error", "stderr", "standard_error", "se_beta",
          "beta_se", "sebeta"),
  p   = c("p", "pval", "p_value", "pvalue", "p_wald", "gc_pvalue",
          "p.value"),
  eaf = c("eaf", "af", "maf", "freq", "frequency", "effect_allele_freq",
          "ea_freq", "a1_freq", "allele_freq", "raf"),
  n   = c("n", "n_samples", "sample_size", "neff", "n_eff")
)

#' Coerce a data frame or summary-statistics file into a `pmr_sumstats` object
#'
#' `import_sumstats()` is the standard entry point for GWAS summary statistics
#' in PleioMatchR.  It recognises common column names used by the GWAS
#' literature and by `TwoSampleMR` (e.g. `SNP`, `effect_allele`,
#' `other_allele`, `beta`, `se`, `pval`, `eaf`, `chr`, `pos`).  Allele
#' frequencies are interpreted as the frequency of the effect allele.
#'
#' @param x A data.frame of summary statistics, or a path to a plain-text
#'   (optionally `.gz`-compressed) file with a header row.
#' @param ... Reserved for future arguments.
#'
#' @return A data.frame with class `c("pmr_sumstats", "data.frame")` and
#'   canonical columns: `snp`, `chr`, `pos`, `ea`, `oa`, `beta`, `se`, `p`,
#'   `eaf`, `maf`, `n`.
#' @export
#' @examples
#' x <- data.frame(SNP = c("rs1", "rs2"), chr = c(1, 1), pos = c(1000, 9000),
#'                 EA = c("A", "C"), OA = c("G", "T"), beta = c(0.1, -0.2),
#'                 se = c(0.03, 0.04), p = c(0.001, 0.01),
#'                 eaf = c(0.4, 0.6))
#' str(import_sumstats(x))
import_sumstats <- function(x, ...) {
  if (is.character(x) && length(x) == 1L) {
    x <- .read_sumstats_file(x)
  }
  if (!is.data.frame(x)) {
    stop("`x` must be a data.frame or a path to a summary-statistics file.",
         call. = FALSE)
  }
  norm <- .normalise_sumstats(x)
  norm
}

#' @export
print.pmr_sumstats <- function(x, ...) {
  cat("PleioMatchR summary statistics: ", nrow(x), " variant(s)\n", sep = "")
  cat("  chr range: ", min(x$chr, na.rm = TRUE), "-",
      max(x$chr, na.rm = TRUE), "\n", sep = "")
  cat("  p-values present: ", sum(!is.na(x$p)), " | beta/se present: ",
      sum(!is.na(x$beta) & !is.na(x$se)), "\n", sep = "")
  invisible(x)
}

.read_sumstats_file <- function(path) {
  if (!file.exists(path)) stop("File not found: ", path, call. = FALSE)
  first <- readLines(path, n = 1L, warn = FALSE)
  sep <- if (grepl(",", first)) "," else if (grepl("\t", first)) "\t" else ""
  utils::read.table(path, header = TRUE, sep = sep, stringsAsFactors = FALSE,
                    check.names = FALSE, comment.char = "")
}

.normalise_sumstats <- function(x, need_coords = TRUE) {
  orig <- x
  names(orig) <- tolower(trimws(names(orig)))
  hit <- function(kind) names(orig)[names(orig) %in% .pleio_aliases[[kind]]]
  col_of <- function(kind) {
    h <- hit(kind)
    if (length(h) == 0L) return(NULL)
    orig[[h[1L]]]
  }

  out <- data.frame(.row = seq_len(nrow(orig)), stringsAsFactors = FALSE)
  out$snp <- as.character(col_of("snp"))
  chr_raw <- col_of("chr")
  pos_raw <- col_of("pos")
  if (need_coords && (is.null(chr_raw) || is.null(pos_raw))) {
    stop("Neither `chr`/`pos` nor a recognised alias was found. PleioMatchR ",
         "requires genomic coordinates for window-based analysis.",
         call. = FALSE)
  }
  out$chr <- if (!is.null(chr_raw)) .encode_chr(chr_raw) else NA_real_
  out$pos <- if (!is.null(pos_raw)) suppressWarnings(as.numeric(pos_raw))
  else NA_real_
  if (need_coords) {
    if (anyNA(out$pos)) {
      stop("`pos` contains non-numeric values.", call. = FALSE)
    }
  }
  if (is.null(out$snp)) {
    if (need_coords) {
      out$snp <- paste0(out$chr, ":", out$pos)
    } else {
      stop("A SNP identifier column is required when coordinates are absent.",
           call. = FALSE)
    }
  }

  ea_raw <- col_of("ea")
  oa_raw <- col_of("oa")
  if (is.null(ea_raw) && !is.null(oa_raw)) ea_raw <- oa_raw
  if (is.null(oa_raw) && !is.null(ea_raw)) oa_raw <- ea_raw
  out$ea <- toupper(as.character(ea_raw %||% NA_character_))
  out$oa <- toupper(as.character(oa_raw %||% NA_character_))
  bad_allele <- !is.na(out$ea) & !out$ea %in% c("A", "C", "G", "T")
  if (any(bad_allele)) {
    warning(sum(bad_allele), " effect alleles are not A/C/G/T; set to NA.",
            call. = FALSE)
    out$ea[bad_allele] <- NA_character_
  }
  bad_allele2 <- !is.na(out$oa) & !out$oa %in% c("A", "C", "G", "T")
  if (any(bad_allele2)) {
    warning(sum(bad_allele2), " other alleles are not A/C/G/T; set to NA.",
            call. = FALSE)
    out$oa[bad_allele2] <- NA_character_
  }

  num <- function(kind) {
    v <- col_of(kind)
    if (is.null(v)) return(rep(NA_real_, nrow(out)))
    suppressWarnings(as.numeric(as.character(v)))
  }
  out$beta <- num("beta")
  out$se <- num("se")
  out$p <- num("p")
  out$eaf <- num("eaf")
  out$n <- num("n")
  out$maf <- pmin(out$eaf, 1 - out$eaf, na.rm = TRUE)
  if (!any(!is.na(out$p)) && !any(!is.na(out$beta))) {
    stop("No `p` or `beta` column found; at least one is required.",
         call. = FALSE)
  }
  if (anyDuplicated(out$snp) && any(!is.na(out$snp))) {
    warning(sum(duplicated(out$snp)), " duplicated SNP identifiers found.",
            call. = FALSE)
  }
  attr(out, "n_input") <- nrow(orig)
  out$.row <- NULL
  class(out) <- c("pmr_sumstats", "data.frame")
  out
}

.encode_chr <- function(chr_raw) {
  ch <- as.character(chr_raw)
  ch <- sub("^chr", "", ch, ignore.case = TRUE)
  out <- suppressWarnings(as.numeric(ch))
  out[ch == "X"] <- 23
  out[ch == "Y"] <- 24
  out[ch == "MT"] <- 25
  out[ch == "M"] <- 25
  if (anyNA(out)) {
    bad <- unique(ch[is.na(out)])
    stop("Unrecognised chromosome values: ", paste(bad, collapse = ", "),
         call. = FALSE)
  }
  out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.is_pmr <- function(x, what = "pmr_sumstats") inherits(x, what)

.as_sentinels <- function(x) {
  if (.is_pmr(x)) return(x)
  import_sumstats(x)
}

.req_chr_pos <- function(x, fname) {
  if (is.null(x$chr) || is.null(x$pos)) {
    stop(fname, " requires genomic coordinates (`chr`, `pos`).",
         call. = FALSE)
  }
  invisible(NULL)
}

.req_maf <- function(x, fname) {
  if (is.null(x$maf) || all(is.na(x$maf))) {
    stop(fname, " requires effect-allele frequency (`eaf`/`maf`) for matching.",
         call. = FALSE)
  }
  invisible(NULL)
}

## Allele helpers -------------------------------------------------------------

.is_palindromic <- function(a1, a2) {
  p <- is.na(a1) | is.na(a2)
  ok <- !p & ((a1 == "A" & a2 == "T") | (a1 == "T" & a2 == "A") |
              (a1 == "C" & a2 == "G") | (a1 == "G" & a2 == "C"))
  ok[is.na(ok)] <- FALSE
  ok
}

.same_alleles <- function(a, b) {
  a == b
}

## Fast window scanner ---------------------------------------------------------

#' @importFrom stats setNames
.split_by_chr <- function(pos, chr) {
  split(pos, factor(chr, levels = unique(chr)))
}

#' For each query (chr, pos) find, within +/- `window` bp, the minimum p-value
#' and the index (into `outcome`) of the lead variant.
.window_scan <- function(query_chr, query_pos, outcome, window,
                         p_threshold = NULL) {
  chr_levels <- unique(query_chr)
  idx <- integer(length(query_chr))
  minp <- rep(NA_real_, length(query_chr))
  hit <- rep(FALSE, length(query_chr))
  for (cc in chr_levels) {
    qq <- which(query_chr == cc)
    oo <- which(outcome$chr == cc)
    if (length(oo) == 0L) next
    op <- outcome$pos[oo]
    opos_sorted <- order(op)
    op <- op[opos_sorted]
    op_id <- oo[opos_sorted]
    op_p <- outcome$p[op_id]
    for (j in seq_along(qq)) {
      lo <- findInterval(query_pos[qq[j]] - window, op)
      hi <- findInterval(query_pos[qq[j]] + window, op)
      if (hi > lo) {
        sel <- (lo + 1L):hi
        sel_p <- op_p[sel]
        w <- which.min(sel_p)
        idx[qq[j]] <- op_id[sel[w]]
        minp[qq[j]] <- sel_p[w]
        if (!is.null(p_threshold)) {
          hit[qq[j]] <- any(sel_p <= p_threshold)
        }
      }
    }
  }
  list(index = idx, p = minp, hit = hit)
}
