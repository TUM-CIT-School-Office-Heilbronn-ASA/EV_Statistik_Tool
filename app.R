library(tidyverse)
library(R6)
library(shiny)
library(here)
library(purrr)

# Configure R for better error reporting in Shiny
options(
  shiny.error = function() {
    cat("Error occurred:\n")
    traceback(max.lines = 20)
  },
  shiny.sanitize.errors = FALSE,  # Show full error messages (use with caution in production)
  warn = 1  # Show warnings immediately
)

import <- function(path) {
  if (!exists(sub(".R$", "", tail(unlist(strsplit(path, "/")), 1)), mode = "environment")) {
    source(here(path))
  }
}

import("View/MainView.R")
import("Controller/MainController.R")
import("Model/PlotGenerator.R")

app <- R6::R6Class(
  "app",
  public = list(
    #' Initialize application wiring view and controller
    initialize = function() {
      config <- private$get_plot_config()
      private$view <- main_view$new(config)
      private$controller <- main_controller$new(config)
      invisible(self)
    },
    #' Run Shiny application
    run = function(...) {
      shinyApp(
        ui = private$view$get_ui(),
        server = private$controller$get_server(),
        ...
      )
    }
  ),
  private = list(
    view = NULL,
    controller = NULL,
    get_plot_config = function() {
      tibble(
        value = c("application_date", "admission_date", "date_difference", "points_step1"),
        label = c(
          "Bewerbungszeitpunktverteilung",
          "Zulassungszeitpunktverteilung",
          "Zulassungszeitpunktdifferenz",
          "Punkte aus Stufe 1"
        ),
        tab_name = c(
          "Bewerbungszeitpunkt",
          "Zulassungszeitpunkt",
          "Zulassungsdifferenz",
          "Punkte Stufe 1"
        ),
        pattern = c(
          ".*Bewerbungen.*",
          ".*Zulassungen.*",
          ".*Differenzen.*",
          ".*PunkteAusStufe1.*"
        ),
        output_dist = c(
          "plot_application_dist",
          "plot_admission_dist",
          "plot_difference_dist",
          "plot_points_dist"
        ),
        output_cum = c(
          "plot_application_cum",
          "plot_admission_cum",
          "plot_difference_cum",
          "plot_points_cum"
        ),
        method = c(
          "process_file_application_date",
          "process_file_admission_date",
          "process_file_application_admission_date_difference",
          "process_file_points_step1"
        )
      )
    }
  )
)

# Launch the app
app_instance <- app$new()
app_instance$run()