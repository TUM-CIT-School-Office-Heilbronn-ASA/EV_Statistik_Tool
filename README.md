# EV Statistik Tool

Shiny application for visualizing and analyzing EV applicant data.

## Table of Contents
- [User Manual](#user-manual)
  - [High level features](#high-level-features)
  - [How to start the program](#how-to-start-the-program)
  - [How to use the program](#how-to-use-the-program)
  - [How to stop the program](#how-to-stop-the-program)
- [Developer Manual](#developer-manual)
  - [Core technologies](#core-technologies)
  - [Project structure](#project-structure)
  - [Configuration](#configuration)
  - [Start/stop with Docker](#startstop-with-docker)
  - [Start/stop without Docker](#startstop-without-docker)
  - [Linting rules](#linting-rules)
- [License](#license)

## User Manual

### High level features
- Interactive Shiny UI to explore EV applicant data.
- Visualizations and tables (ggplot2/plotly/DT) for key metrics.
- Clear separation of Controller/Model/View for transparency of app logic.

### How to start the program
#### Using Docker (recommended)
1. Start the containers:
   - **Windows (PowerShell / CMD):**
     ```cmd
     start-docker.bat
     ```
   - **macOS / Linux (Terminal):**
     ```bash
     ./start-docker.sh
     ```
   - **macOS double-click:** `Start EV Planning Tool.app`
2. Open the app at http://localhost:3838.

#### Without Docker (local R)
1. Ensure R 4.3+ is installed.
2. Install required packages (once):
   ```r
   install.packages(c("tidyverse","R6","here","purrr","zip","png",
                      "shinyjs","shinydashboard","checkmate","glue","DT",
                      "plotly","htmlwidgets","jsonlite","readr","stringr",
                      "forcats","scales","lubridate","e1071"))
   ```
3. Start the app:
   ```r
   shiny::runApp(".")
   ```

### How to use the program
1. Open http://localhost:3838 after starting (Docker or local).
2. Use the navigation in the Shiny UI to select views/plots and filter applicant data.
3. Export or inspect tables/plots as provided by the interface controls.

### How to stop the program
- **Docker:**  
  - Windows: `stop-docker.bat`  
  - macOS / Linux: `./stop-docker.sh`  
  - macOS double-click: `Stop EV Planning Tool.app`
- **Local R:** Stop the R session (e.g., Ctrl+C in the R console or stop the Shiny run).

## Developer Manual

### Core technologies
- R 4.3+, Shiny, tidyverse, plotly, DT, R6.
- Containerization with Docker/Docker Compose for reproducible runtime.

### Project structure
- `app.R` – Shiny entrypoint.
- `Controller/` – Control logic and data preparation.
- `Model/` – Data and computation logic.
- `View/` – UI components and visualizations.
- `Dockerfile`, `docker-compose.yml` – Container setup.
- `binder/environment.yml` – Binder/Jupyter dependency pinning.
- Start/stop scripts (`start/stop-docker.*`, macOS `.app` launchers).

### Configuration
- Defaults are baked into the app; Docker exposes the app on port `3838`.
- Environment variables for Shiny logging are set in `docker-compose.yml` (`SHINY_LOG_STDERR=1`, `SHINY_LOG_STDOUT=1`).

### Start/stop with Docker
- Start: `npm run start:docker` or run the platform scripts (`start-docker.*`, macOS app).
- Stop: `npm run stop:docker` or the matching stop scripts (`stop-docker.*`, macOS app).
- Compose directly: `docker-compose up --build -d` / `docker-compose down`.

### Start/stop without Docker
- Install R 4.3+ and the listed packages, then run:
  ```r
  shiny::runApp(".")
  ```
- Stop the local R/Shiny session when finished.

### Linting rules
- R: `lintr` with `line_length_linter(120)` (see `.lintr`).
- CSS: Stylelint rules in `.stylelintrc.json` (if Stylelint is installed).

## License
See [LICENSE](LICENSE).
