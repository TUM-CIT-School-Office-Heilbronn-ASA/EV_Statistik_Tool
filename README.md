# EV Statistik Tool

The EV Statistik Tool is an R/Shiny application for uploading EV applicant data
from CSV files, generating distribution and cumulative plots, and downloading
the results as a ZIP archive.

## User-Manual

### High level features
- Uploads a single `.csv` file with applicant data.
- Generates distribution and cumulative plots for application date, admission
  date, admission date difference, and step-1 points.
- Lets users choose which plot types to generate.
- Shows plots in tabbed views.
- Downloads all generated plots as a ZIP file.

### How to start the program
You do not need to know R or Docker. Follow the steps below:

1. Make sure Docker Desktop is installed and running.
   If you do not have it, ask your technical contact to install it for you.
2. Open the project folder on your computer.
3. Start the program:
   - Windows: double-click `start-docker.bat`
   - macOS: double-click `Start EV Planning Tool.app`
   - Linux: open a Terminal in the folder and run `./start-docker.sh`
4. The script waits until the app is ready and opens `http://localhost:3838`
   automatically in your browser. The first start can take a few minutes.

The app opens in your browser and runs locally on your machine.

### How to use the program
1. Upload your applicant data.
   - In the sidebar, click **Browse...** and select a `.csv` file.
2. Select plot types.
   - Use **Zu erstellende Plots** to choose which plots to generate.
3. Create plots.
   - Click **Plots erstellen**.
4. Review results.
   - Plots appear in tabs (distribution and cumulative).
5. Download the plots.
   - Click **Plots herunterladen (ZIP)** to download a ZIP file.
6. Clear the state if you want to start over.
   - Click **Reset Plots**.

After **Plots erstellen**, the app stores the generated PNG files in a temporary
folder and includes them in the download ZIP.

### How to stop the program
1. Stop the app:
   - Windows: double-click `stop-docker.bat`
   - macOS: double-click `Stop EV Planning Tool.app`
   - Linux: run `./stop-docker.sh`
2. Close the browser tab.

## Developer-Manual

### Core technologies
- R 4.3.x and Shiny for the web app.
- R6 for MVVM-style separation (Controller, Model, View).
- tidyverse, plotly, DT, shinyjs, shinydashboard, checkmate for data handling
  and UI.
- Docker image based on `rocker/shiny:4.3.1`.
- Docker Compose for local orchestration.

### Project structure
- `app.R`: Application entrypoint, wires Controller/Model/View.
- `Controller/`: Shiny server logic and plot orchestration.
- `Model/`: Plot generation and data validation.
- `View/`: Shiny UI components and layout.
- `Dockerfile`, `docker-compose.yml`: Container build and runtime definition.
- `start-docker.*`, `stop-docker.*`, macOS `.app` launchers: helper scripts.

### Configuration
Plot types and tabs are configured in `app.R` inside `get_plot_config()`:
- `value`, `label`, `tab_name`: UI labels and identifiers.
- `output_dist`, `output_cum`: output IDs for plots.
- `method`: plot generator method to call.

After editing `app.R`, restart the app to load changes.

### Start/stop with Docker
Start with the helper scripts (detached, with readiness check and auto-open):
- macOS: `Start EV Planning Tool.app` or `./start-docker.sh`
- Linux: `./start-docker.sh`
- Windows: `start-docker.bat`

Or start directly:
```sh
docker compose up --build
```

The app binds to port 3838 by default. To change the host port, update the
mapping in `docker-compose.yml` (for example, `8080:3838`).

Stop with the helper scripts:
- macOS: `Stop EV Planning Tool.app` or `./stop-docker.sh`
- Linux: `./stop-docker.sh`
- Windows: `stop-docker.bat`

Or stop directly:
```sh
docker compose down
```

### Start/stop without Docker
1. Install R (4.3.x recommended).
2. Install dependencies:
```r
install.packages(c(
  "shiny",
  "shinydashboard",
  "shinyjs",
  "DT",
  "R6",
  "tidyverse",
  "checkmate",
  "glue",
  "here",
  "purrr",
  "zip",
  "png",
  "plotly",
  "htmlwidgets",
  "jsonlite",
  "readr",
  "stringr",
  "forcats",
  "scales",
  "lubridate",
  "e1071"
))
```

3. Run from the repo root:
```sh
R -e "shiny::runApp('.')"
```

To use a custom port, set the option before running:
```sh
R -e "options(shiny.port = 3838); shiny::runApp('.')"
```

### Linting rules
- R: `lintr` with `line_length_linter(120)` (see `.lintr`).
- CSS: Stylelint rules in `.stylelintrc.json` (if Stylelint is installed).
