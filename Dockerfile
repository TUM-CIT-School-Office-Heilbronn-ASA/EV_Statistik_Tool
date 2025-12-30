FROM rocker/shiny:4.3.1

LABEL maintainer="TUM-CIT-School-Office-Heilbronn-ASA"

# Install system dependencies required by tidyverse/plotly and friends
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages used by the app
RUN install2.r --error \
    tidyverse \
    R6 \
    here \
    purrr \
    zip \
    png \
    shinyjs \
    shinydashboard \
    checkmate \
    glue \
    DT \
    plotly \
    htmlwidgets \
    jsonlite \
    readr \
    stringr \
    forcats \
    scales \
    lubridate \
    e1071

WORKDIR /srv/shiny-server/app

COPY . /srv/shiny-server/app

RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
