# EV Statistik Tool

R Shiny Anwendung zur Visualisierung und Auswertung von EV-Bewerberdaten.

## Inhalt
- [Funktionen](#funktionen)
- [Voraussetzungen](#voraussetzungen)
- [Schnellstart mit Docker](#schnellstart-mit-docker)
- [Lokaler Start ohne Docker](#lokaler-start-ohne-docker)
- [Projektstruktur](#projektstruktur)
- [Nützliche Skripte](#nützliche-skripte)
- [Linting](#linting)
- [Lizenz](#lizenz)

## Funktionen
- Interaktive Shiny-Oberfläche zur Auswertung der Bewerberdaten.
- Visualisierungen und Tabellen (ggplot2/plotly/DT) zur Exploration der Kennzahlen.
- Trennung in Controller/Model/View für nachvollziehbare App-Logik.

## Voraussetzungen
- [Docker Desktop](https://www.docker.com/products/docker-desktop) oder Docker Engine mit `docker-compose`.
- Optional: R 4.3+ zum lokalen Start ohne Container.

## Schnellstart mit Docker
1. Starte die Container:
   - **Windows (PowerShell / CMD):**
     ```cmd
     start-docker.bat
     ```
   - **macOS / Linux (Terminal):**
     ```bash
     ./start-docker.sh
     ```
   - **macOS per Doppelklick:** `Start EV Planning Tool.app`
2. Öffne die Anwendung unter http://localhost:3838.
3. Zum Stoppen:
   - Windows: `stop-docker.bat`
   - macOS / Linux: `./stop-docker.sh`
   - macOS per Doppelklick: `Stop EV Planning Tool.app`

## Lokaler Start ohne Docker
1. Benötigte Pakete installieren (einmalig):
   ```r
   install.packages(c("tidyverse","R6","here","purrr","zip","png",
                      "shinyjs","shinydashboard","checkmate","glue","DT",
                      "plotly","htmlwidgets","jsonlite","readr","stringr",
                      "forcats","scales","lubridate","e1071"))
   ```
2. App starten:
   ```r
   shiny::runApp(".")
   ```

## Projektstruktur
- `app.R` – Einstiegspunkt der Shiny-App.
- `Controller/` – Steuerlogik und Datenaufbereitung.
- `Model/` – Daten- und Berechnungslogik.
- `View/` – UI-Komponenten und Visualisierungen.
- `Dockerfile`, `docker-compose.yml` – Container-Setup.
- `binder/environment.yml` – Abhängigkeiten für Binder/Jupyter.
- Start/Stop-Skripte (`start/stop-docker.*`, macOS `.app`).
- Linting-Konfigurationen: `.lintr`, `.stylelintrc.json`.

## Nützliche Skripte
- `npm run start:docker` / `npm run stop:docker` – Container per npm-Skripte.
- `start-docker.*` / `stop-docker.*` – Plattformabhängige Start-/Stop-Skripte.
- macOS: `Start EV Planning Tool.app` / `Stop EV Planning Tool.app` (Doppelklick).

## Linting
- R: `lintr` mit `line_length_linter(120)` (siehe `.lintr`).
- CSS: Stylelint-Regeln in `.stylelintrc.json` (wenn Stylelint installiert ist).

## Lizenz
Siehe [LICENSE](LICENSE).
