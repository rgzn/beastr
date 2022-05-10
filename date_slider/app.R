# Interactive Data Map
#
# Based off of https://rstudio.github.io/leaflet/shiny.html
#

library(shiny)
library(leaflet)
library(RColorBrewer)
library(tidyverse)
library(sf)
library(lubridate)
library(mapview)

#dsn = "C:/Users/jweissman/Documents/fisher-gis/test.gpkg"
dsn = "C:/Users/jweissman/Documents/fisher-gis/telemetry.gpkg"
points = st_read(dsn, layer = "animal_fixes", optional = TRUE) %>%
    filter(fix_status == "Valid") %>%
    # mutate(ifelsetime = with_tz(time, tzone = "UTC"))
    # mutate(time = lubridate::with_tz(time, tzone = "US/Pacific")) %>%
    st_transform(4326)



ui <- bootstrapPage(
    tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
    leafletOutput("map", width = "100%", height = "100%"),
    absolutePanel(top = 10, right = 10,
                  selectInput("colors", "Color Scheme",
                              rownames(subset(brewer.pal.info, category %in% c("seq", "div")))
                  ),
                  checkboxInput("legend", "Show legend", TRUE)
    ),
    absolutePanel(bottom = 10, left = 10, width = "80%", draggable = FALSE,
                  sliderInput("range",
                              label = "Time",
                              min = min(points$time),
                              max = max(points$time),
                              value = range(c(max(points$time), max(points$time) - days(7))),
                              step = 1,
                              width = "100%",
                              animate = TRUE)
    )
)

server <- function(input, output, session) {

    # Reactive expression for the data subsetted to what the user selected
    filteredData <- reactive({
        points %>%
            filter(time >= input$range[1],
                   time <= input$range[2])
    })

    # This reactive expression represents the palette function,
    # which changes as the user makes selections in UI.
    colorpal <- reactive({
        colorFactor(input$colors, points$animal_id)
    })

    output$map <- renderLeaflet({
        # Use leaflet() here, and only include aspects of the map that
        # won't need to change dynamically (at least, not unless the
        # entire map is being torn down and recreated).
        # bbox <- st_bbox(points)
        mean_coords <- points %>%
            st_coordinates() %>%
            as_tibble() %>%
            summarise_all(mean)
        points %>%
            group_by(animal_id) %>%
            head(10) %>%
            ungroup() %>%
            mapview(hide = TRUE) %>%
            `@`(map) %>%
            leaflet::addTiles(urlTemplate = "https://img.caltopo.com/tile/mbt/{z}/{x}/{y}.png",
                              layerId = "Mapbuilder Topo",
                              attribution = '<a href="https://caltopo.com">Caltopo</a>') %>%
            setView(mean_coords$X, mean_coords$Y, zoom = 10)
        # addTiles()

        # %>%
        #     fitBounds(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)
    })

    # Incremental changes to the map (in this case, replacing the
    # circles when a new color is chosen) should be performed in
    # an observer. Each independent set of things that can change
    # should be managed in its own observer.
    observe({
        pal <- colorpal()

        leafletProxy("map", data = filteredData()) %>%
            clearMarkers() %>%
            addCircleMarkers(fillColor = ~pal(animal_id),
                             fillOpacity = 0.7,
                             weight = 0.1,
                             radius = 5,
                             popup = ~paste(time))
    })

    # Use a separate observer to recreate the legend as needed.
    observe({
        proxy <- leafletProxy("map", data = points)

        # Remove any existing legend, and only if the legend is
        # enabled, create a new one.
        proxy %>% clearControls()
        if (input$legend) {
            pal <- colorpal()
            proxy %>% addLegend(position = "bottomright",
                                pal = pal, values = ~animal_id
            )
        }
    })
}

shinyApp(ui, server)
