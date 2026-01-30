roxygen_r6_policy_linter <- function() {
  lintr::Linter(function(source_expression) {
    filename <- source_expression$filename
    exprs <- lintr::get_source_expressions(filename)$expressions
    line_vals <- vapply(
      exprs,
      function(expr) if (length(expr$line) == 0) NA_integer_ else expr$line,
      integer(1)
    )
    min_line <- suppressWarnings(min(line_vals, na.rm = TRUE))
    if (!is.finite(min_line)) return(list())
    if (!identical(source_expression$line, min_line)) return(list())
    lines <- readLines(filename, warn = FALSE)
    if (length(lines) == 0) return(list())
    lints <- list()

    strip_line <- function(x) {
      x <- gsub("\"[^\"]*\"|'[^']*'", "", x)
      sub("#.*$", "", x)
    }

    count_parens <- function(x) {
      x <- strip_line(x)
      opens <- nchar(gsub("[^(]", "", x))
      closes <- nchar(gsub("[^)]", "", x))
      opens - closes
    }

    get_roxygen_block <- function(idx) {
      block <- character()
      i <- idx - 1
      while (i >= 1 && grepl("^\\s*#'", lines[i])) {
        block <- c(lines[i], block)
        i <- i - 1
      }
      block
    }

    has_tag <- function(block, tag) {
      any(grepl(paste0("@", tag, "\\b"), block))
    }

    lint_at <- function(line_number, message) {
      list(lintr::Lint(filename, line_number, 1, "warning", message, lines[line_number]))
    }

    parse_list_block <- function(start_idx) {
      depth <- count_parens(lines[start_idx])
      i <- start_idx
      while (i < length(lines) && depth > 0) {
        i <- i + 1
        depth <- depth + count_parens(lines[i])
      }
      start_idx:i
    }

    parse_function_block <- function(start_idx) {
      depth <- 0
      seen_brace <- FALSE
      i <- start_idx
      while (i <= length(lines)) {
        line_clean <- strip_line(lines[i])
        chars <- strsplit(line_clean, "")[[1]]
        for (ch in chars) {
          if (ch == "{") {
            depth <- depth + 1
            seen_brace <- TRUE
          } else if (ch == "}") {
            depth <- depth - 1
          }
          if (seen_brace && depth == 0) {
            return(start_idx:i)
          }
        }
        i <- i + 1
      }
      start_idx
    }

    extract_function_args <- function(start_idx) {
      args_text <- ""
      paren_depth <- 0
      found <- FALSE
      for (i in start_idx:length(lines)) {
        line_clean <- strip_line(lines[i])
        if (!found) {
          pos <- regexpr("function\\s*\\(", line_clean)
          if (pos[1] == -1) next
          start <- pos[1] + attr(pos, "match.length")
          chunk <- substr(line_clean, start, nchar(line_clean))
          found <- TRUE
          paren_depth <- 1
        } else {
          chunk <- line_clean
        }
        chars <- strsplit(chunk, "")[[1]]
        for (ch in chars) {
          if (ch == "(") {
            paren_depth <- paren_depth + 1
            args_text <- paste0(args_text, ch)
            next
          }
          if (ch == ")") {
            paren_depth <- paren_depth - 1
            if (paren_depth <= 0) {
              return(args_text)
            }
            args_text <- paste0(args_text, ch)
            next
          }
          args_text <- paste0(args_text, ch)
        }
      }
      args_text
    }

    i <- 1
    while (i <= length(lines)) {
      line_clean <- strip_line(lines[i])
      if (grepl("R6Class\\s*\\(", line_clean)) {
        class_block <- parse_list_block(i)
        roxy <- get_roxygen_block(i)
        if (!has_tag(roxy, "title")) {
          lints <- c(lints, lint_at(i, "R6 class is missing @title roxygen tag."))
        }
        if (!has_tag(roxy, "description")) {
          lints <- c(lints, lint_at(i, "R6 class is missing @description roxygen tag."))
        }

        field_names <- character()
        public_list <- grepl("\\bpublic\\s*=\\s*list\\s*\\(", lines[class_block])
        private_list <- grepl("\\bprivate\\s*=\\s*list\\s*\\(", lines[class_block])
        list_starts <- class_block[public_list | private_list]
        for (start in list_starts) {
          list_block <- parse_list_block(start)
          idx <- min(list_block)
          while (idx <= max(list_block)) {
            entry_line <- strip_line(lines[idx])
            if (grepl("^\\s*[A-Za-z][A-Za-z0-9_.]*\\s*=\\s*function\\s*\\(", entry_line)) {
              fn_block <- parse_function_block(idx)
              idx <- max(fn_block) + 1
              next
            }
            if (grepl("\\b(public|private)\\s*=\\s*list\\s*\\(", entry_line)) {
              idx <- idx + 1
              next
            }
            match <- regexpr("^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*=", entry_line, perl = TRUE)
            if (match[1] != -1) {
              name <- sub("^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*=.*$", "\\1", entry_line)
              field_names <- unique(c(field_names, name))
            }
            idx <- idx + 1
          }
        }

        if (length(field_names) > 0) {
          for (field in field_names) {
            if (!any(grepl(paste0("@field\\s+", field, "\\b"), roxy))) {
              lints <- c(lints, lint_at(i, sprintf("R6 field '%s' is missing @field roxygen tag.", field)))
            }
          }
        }

        public_list <- grepl("\\bpublic\\s*=\\s*list\\s*\\(", lines[class_block])
        private_list <- grepl("\\bprivate\\s*=\\s*list\\s*\\(", lines[class_block])
        list_starts <- class_block[public_list | private_list]
        for (start in list_starts) {
          method_block <- parse_list_block(start)
          idx <- min(method_block)
          while (idx <= max(method_block)) {
            entry_line <- strip_line(lines[idx])
            if (!grepl("^\\s*[A-Za-z][A-Za-z0-9_.]*\\s*=\\s*function\\s*\\(", entry_line)) {
              idx <- idx + 1
              next
            }
            method_name <- sub("^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*=.*$", "\\1", entry_line)
            is_constructor <- identical(method_name, "initialize")
            roxy_method <- get_roxygen_block(idx)
            if (!has_tag(roxy_method, "description")) {
              lints <- c(lints, lint_at(idx, "Method is missing @description roxygen tag."))
            }
            if (!is_constructor && !has_tag(roxy_method, "details")) {
              lints <- c(lints, lint_at(idx, "Method is missing @details roxygen tag."))
            }
            if (!is_constructor && !has_tag(roxy_method, "return")) {
              lints <- c(lints, lint_at(idx, "Method is missing @return roxygen tag."))
            }
            args_text <- extract_function_args(idx)
            args_clean <- gsub("[[:space:],]", "", args_text)
            if (nchar(args_clean) > 0 && !has_tag(roxy_method, "param")) {
              lints <- c(lints, lint_at(idx, "Method is missing @param roxygen tag(s)."))
            }
            fn_block <- parse_function_block(idx)
            idx <- max(fn_block) + 1
          }
        }

        i <- max(class_block) + 1
      } else {
        i <- i + 1
      }
    }

    Filter(Negate(is.null), lints)
  })
}

r6_method_policy_linter <- function(max_loc = 30) {
  lintr::Linter(function(source_expression) {
    filename <- source_expression$filename
    exprs <- lintr::get_source_expressions(filename)$expressions
    line_vals <- vapply(
      exprs,
      function(expr) if (length(expr$line) == 0) NA_integer_ else expr$line,
      integer(1)
    )
    min_line <- suppressWarnings(min(line_vals, na.rm = TRUE))
    if (!is.finite(min_line)) return(list())
    if (!identical(source_expression$line, min_line)) return(list())
    lines <- readLines(filename, warn = FALSE)
    if (length(lines) == 0) return(list())
    lints <- list()

    strip_line <- function(x) {
      x <- gsub("\"[^\"]*\"|'[^']*'", "", x)
      sub("#.*$", "", x)
    }

    count_parens <- function(x) {
      x <- strip_line(x)
      opens <- nchar(gsub("[^(]", "", x))
      closes <- nchar(gsub("[^)]", "", x))
      opens - closes
    }

    parse_list_block <- function(start_idx) {
      depth <- count_parens(lines[start_idx])
      i <- start_idx
      while (i < length(lines) && depth > 0) {
        i <- i + 1
        depth <- depth + count_parens(lines[i])
      }
      start_idx:i
    }

    parse_function_block <- function(start_idx) {
      depth <- 0
      seen_brace <- FALSE
      i <- start_idx
      while (i <= length(lines)) {
        line_clean <- strip_line(lines[i])
        chars <- strsplit(line_clean, "")[[1]]
        for (ch in chars) {
          if (ch == "{") {
            depth <- depth + 1
            seen_brace <- TRUE
          } else if (ch == "}") {
            depth <- depth - 1
          }
          if (seen_brace && depth == 0) {
            return(start_idx:i)
          }
        }
        i <- i + 1
      }
      start_idx
    }

    body_start_index <- function(block, start_idx) {
      for (idx in block) {
        line_clean <- strip_line(lines[idx])
        brace_pos <- regexpr("\\{", line_clean)
        if (brace_pos[1] != -1) {
          after <- substr(line_clean, brace_pos[1] + 1, nchar(line_clean))
          after_trim <- trimws(gsub("[{}()]", "", after))
          if (nchar(after_trim) > 0) {
            return(idx)
          }
          return(min(idx + 1, max(block)))
        }
      }
      start_idx
    }

    count_loc <- function(block, start_idx) {
      body_start <- body_start_index(block, start_idx)
      idxs <- block[block >= body_start]
      count <- 0
      for (idx in idxs) {
        line_clean <- strip_line(lines[idx])
        line_clean <- trimws(line_clean)
        if (line_clean == "") next
        line_clean <- trimws(gsub("[{}()]", "", line_clean))
        if (line_clean == "") next
        count <- count + 1
      }
      count
    }

    has_explicit_return <- function(block, start_idx) {
      body_start <- body_start_index(block, start_idx)
      idxs <- block[block >= body_start]
      for (idx in idxs) {
        line_clean <- strip_line(lines[idx])
        if (grepl("\\breturn\\s*\\(", line_clean)) return(TRUE)
      }
      FALSE
    }

    control_braced <- function(start_idx, keyword) {
      paren_depth <- 0
      seen_paren <- FALSE
      for (i in start_idx:length(lines)) {
        line_clean <- strip_line(lines[i])
        if (i == start_idx) {
          pos <- regexpr(paste0("\\b", keyword, "\\b"), line_clean, perl = TRUE)
          if (pos[1] == -1) return(list(has_brace = TRUE, end_idx = start_idx))
          line_clean <- substr(line_clean, pos[1] + attr(pos, "match.length"), nchar(line_clean))
        }
        chars <- strsplit(line_clean, "")[[1]]
        for (j in seq_along(chars)) {
          ch <- chars[[j]]
          if (!seen_paren) {
            if (ch == "(") {
              seen_paren <- TRUE
              paren_depth <- 1
            }
            next
          }
          if (ch == "(") paren_depth <- paren_depth + 1
          if (ch == ")") paren_depth <- paren_depth - 1
          if (seen_paren && paren_depth == 0) {
            if (j < length(chars)) {
              rest <- paste(chars[(j + 1):length(chars)], collapse = "")
              if (grepl("\\{", rest)) return(list(has_brace = TRUE, end_idx = i))
            }
            k <- i + 1
            while (k <= length(lines)) {
              next_line <- strip_line(lines[k])
              if (nchar(trimws(next_line)) == 0) {
                k <- k + 1
                next
              }
              if (grepl("\\{", next_line)) return(list(has_brace = TRUE, end_idx = k))
              return(list(has_brace = FALSE, end_idx = k))
            }
            return(list(has_brace = FALSE, end_idx = i))
          }
        }
      }
      list(has_brace = TRUE, end_idx = start_idx)
    }

    lint_at <- function(line_number, message) {
      list(lintr::Lint(filename, line_number, 1, "warning", message, lines[line_number]))
    }

    i <- 1
    while (i <= length(lines)) {
      line_clean <- strip_line(lines[i])
      if (grepl("R6Class\\s*\\(", line_clean)) {
        class_block <- parse_list_block(i)
        public_list <- grepl("\\bpublic\\s*=\\s*list\\s*\\(", lines[class_block])
        private_list <- grepl("\\bprivate\\s*=\\s*list\\s*\\(", lines[class_block])
        list_starts <- class_block[public_list | private_list]
        for (start in list_starts) {
          list_block <- parse_list_block(start)
          idx <- min(list_block)
          while (idx <= max(list_block)) {
            entry_line <- strip_line(lines[idx])
            if (!grepl("^\\s*[A-Za-z][A-Za-z0-9_.]*\\s*=\\s*function\\s*\\(", entry_line)) {
              idx <- idx + 1
              next
            }
            method_name <- sub("^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*=.*$", "\\1", entry_line)
            method_block <- parse_function_block(idx)
            loc <- count_loc(method_block, idx)
            if (loc > max_loc) {
              msg <- sprintf("Method '%s' exceeds %d LOC (%d LOC).", method_name, max_loc, loc)
              lints <- c(lints, lint_at(idx, msg))
            }
            if (!has_explicit_return(method_block, idx)) {
              msg <- sprintf("Method '%s' is missing an explicit return().", method_name)
              lints <- c(lints, lint_at(idx, msg))
            }
            block_start <- min(method_block)
            block_end <- max(method_block)
            scan_idx <- block_start
            while (scan_idx <= block_end) {
              scan_line <- strip_line(lines[scan_idx])
              keyword <- NULL
              if (grepl("^\\s*if\\s*\\(", scan_line)) {
                keyword <- "if"
              } else if (grepl("^\\s*for\\s*\\(", scan_line)) {
                keyword <- "for"
              } else if (grepl("^\\s*while\\s*\\(", scan_line)) {
                keyword <- "while"
              } else if (grepl("^\\s*switch\\s*\\(", scan_line)) {
                keyword <- "switch"
              }
              if (!is.null(keyword)) {
                brace_check <- control_braced(scan_idx, keyword)
                if (!brace_check$has_brace) {
                  msg <- sprintf("Method '%s' has %s without curly braces.", method_name, keyword)
                  lints <- c(lints, lint_at(scan_idx, msg))
                }
                scan_idx <- max(scan_idx + 1, brace_check$end_idx)
                next
              }
              scan_idx <- scan_idx + 1
            }
            idx <- max(method_block) + 1
          }
        }
        i <- max(class_block) + 1
      } else {
        i <- i + 1
      }
    }

    Filter(Negate(is.null), lints)
  })
}
