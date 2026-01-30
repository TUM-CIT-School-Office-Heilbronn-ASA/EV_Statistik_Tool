if (!requireNamespace("lintr", quietly = TRUE)) {
  stop("lintr is required. Install it with install.packages('lintr').")
}

targets <- c("app.R", "Model", "ViewModel", "View")
results <- list()

for (target in targets) {
  if (dir.exists(target)) {
    results[[target]] <- lintr::lint_dir(target)
  } else if (file.exists(target)) {
    results[[target]] <- lintr::lint_file(target)
  }
}

lints <- unlist(results, recursive = FALSE)
if (length(lints) > 0) {
  print(lints)
  quit(status = 1)
}
