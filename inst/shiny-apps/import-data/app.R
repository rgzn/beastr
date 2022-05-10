#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/


# DEVNOTE:
# It's very difficult to modify local files from within Shiny,
# so I'm not sure where to go. This is a huge problem, and this app doesn't
# work.
#

library(shiny)
library(beastr)
# library(shinythemes)
library(DT)
library(sf)

ui <- fluidPage(
    # theme = shinytheme("slate"),
    titlePanel("Lotek GPS Data Import"),

    sidebarLayout(
        sidebarPanel(
            fileInput("database",
                      "Your Telemetry Geopackage",
                      accept = c(".gpkg", ".sqlite"),
                      multiple = FALSE),
            fileInput("fix_files",
                      "PinPoint text files for Import",
                      accept = ".txt",
                      multiple = TRUE),
            actionButton("import_button", "Import Data")
        ),
        # sidebarPanel(
        #     tableOutput("import_files")
        # ),
        mainPanel(
            titlePanel("Database Contents:"),
            verbatimTextOutput("database"),
            titlePanel("Data to Import:"),
            DT::dataTableOutput("import_fixes")
            #tableOutput("import_fixes")
        )
    ),
    ui_download <- fluidRow(
        column(width = 12, downloadButton("download",
                                          label = "Write Geopackage",
                                          class = "btn-block"))
    )
)

server <- function(input, output, session) {

    # Server-Wide Variables
    # These are persistent for the session of the server,
    # So they can be re-used between elements.
    imported_fixes <- NULL
    dsn <- NULL

    # Actions
    observeEvent(input$import_button, {
        beastr::append_layer(data = imported_fixes,
                             dsn = dsn,
                             layer = "fixes")
        # session$sendCustomMessage(type = 'testmessage',
        #                          message = 'Thank you for clicking')
    })

    # output$download <- downloadHandler(
    #     filename = function() {
    #         paste0(tools::file_path_sans_ext(input$database$name), ".gpkg")
    #     },
    #     content = function(database) {
    #         data =
    #         sf::st_write(dsn, file, append = FALSE)
    #     }
    # )

    # modifying external files
    # strategy from https://mastering-shiny.org/action-transfer.html
    # Upload -------------------
    input_db <- reactive({
        req(input$database)
        input$database$datapath
    })

    # Append -------------------
    mod_db <- reactive({
        out <- raw()
        if (input$fix_files & input$database) {
            fix_files<- input$fix_files
            req(fix_files)
            tryCatch(
                {
                    beastr::get_id_from_filename(fix_files$name) ->
                        ids
                    beastr::read_lotek(files = fix_files$datapath,
                                       ids = ids) ->
                        imported_fixes
                    beastr::append_layer(data = imported_fixes,
                                         dsn = input$database$datapath,
                                         layer = "fixes")
                },
                error = function(e) {
                    stop(safeError(e))
                })
        }
        input$database$datapath
    })

    # Download -------------------------------------------------------
    output$download <- downloadHandler(
        filename = function() {
            paste0(tools::file_path_sans_ext(input$database$name), ".gpkg")
        },
        content = function(file) {
            fs::file_copy(mod_db(), file)
            # # vroom::vroom_write(tidied(), file)
        }
    )
    #------------------------------------------------------



    output$database <- renderPrint({
        database <- input$database
        req(database)
        database$datapath ->> dsn
        if(!is.null(dsn)) {
            sf::st_layers(dsn) %>%
                print()
        } else {
         "" #empty string
        }

    })



    output$import_files <- renderTable({
        fix_files <- input$fix_files
        req(fix_fixes)
        dplyr::as_tibble(fix_files$datapath)
    })

    output$import_fixes <- DT::renderDT({
        fix_files<- input$fix_files
        req(fix_files)
        #validate(need(ext == "txt", "Please upload a csv file"))
        tryCatch(
            {
                beastr::get_id_from_filename(fix_files$name) ->
                    ids
                beastr::read_lotek(files = fix_files$datapath,
                                   ids = ids) ->>
                    imported_fixes
            },
            error = function(e) {
                stop(safeError(e))
            }
        )
        imported_fixes %>%
            select(-contains("-")) %>%
        DT::datatable(class = c("compact", "stripe"),
                      options = list(
                          lengthMenu = list(c(5, 15, -1), c('5', '15', 'All')),
                          pageLength = 5))
    })

}

shinyApp(ui, server)

