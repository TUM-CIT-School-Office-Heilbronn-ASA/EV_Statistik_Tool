# EV Statistik Tool

R Shiny Anwendung zur Visualisierung und Auswertung von EV-Bewerberdaten.

## Voraussetzungen

- [Docker Desktop](https://www.docker.com/products/docker-desktop) oder Docker Engine mit `docker-compose`.
- Optional: R 4.3+ zum lokalen Start ohne Container.

## Schnellstart (Docker)

- **Windows (PowerShell / CMD):**
  ```cmd
  start-docker.bat
  ```
- **macOS / Linux (Terminal):**
  ```bash
  ./start-docker.sh
  ```
- **macOS per Doppelklick:** `Start EV Planning Tool.app`

Die Anwendung läuft anschließend unter http://localhost:3838.

Zum Stoppen:
- Windows: `stop-docker.bat`
- macOS / Linux: `./stop-docker.sh`
- macOS per Doppelklick: `Stop EV Planning Tool.app`

## Lokaler Start (ohne Docker)

```r
# Benötigte Pakete installieren (einmalig)
install.packages(c("tidyverse","R6","here","purrr","zip","png",
                   "shinyjs","shinydashboard","checkmate","glue","DT",
                   "plotly","htmlwidgets","jsonlite","readr","stringr",
                   "forcats","scales","lubridate","e1071"))

shiny::runApp(".")
```

## Struktur

- `app.R` – Einstiegspunkt der Shiny-App.
- `Controller/`, `Model/`, `View/` – App-Logik, Plot-Erzeugung und UI.
- `Dockerfile`, `docker-compose.yml` – Container-Setup.
- Start/Stop-Skripte (`start/stop-docker.*`, macOS `.app`).
- Linting-Konfigurationen: `.lintr`, `.stylelintrc.json`.

## Linting

- R: `lintr` mit `line_length_linter(120)` (siehe `.lintr`).
- CSS: Stylelint-Regeln in `.stylelintrc.json` (wenn Stylelint installiert ist).

## Lizenz

Siehe [LICENSE](LICENSE).
