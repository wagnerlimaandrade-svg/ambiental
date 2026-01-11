source("R/00_setup.R")
source("R/00_config.R")
source(here::here("app/modules/mod_filters.R"))

df <- read_parquet(FILE_ANALYTICAL)

ui <- fluidPage(
  titlePanel("Desmatamento e Clima no Brasil"),
  sidebarLayout(
    sidebarPanel(
      filtersUI("filters")
    ),
    mainPanel(
      tabsetPanel(
        tabPanel("Tendências", tsUI("ts")),
        tabPanel("Relações", scatterUI("scat")),
        tabPanel("Metodologia", methodologyUI("meth"))
      )
    )
  )
)

server <- function(input, output, session) {
  filtered <- filtersServer("filters", df)
  tsServer("ts", filtered)
  scatterServer("scat", filtered)
}

shinyApp(ui, server)