#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(beastr)
library(shinythemes)
library(DT)

ui <- fluidPage(
    # theme = shinytheme("slate"),
    titlePanel("Lotek GPS Data Import"),

    sidebarLayout(
        sidebarPanel(
            fileInput("fix_files",
                      "Choose PinPoint text files",
                      accept = ".txt",
                      multiple = TRUE),
            # checkboxInput("header", "Header", TRUE)
        ),
        # sidebarPanel(
        #     tableOutput("import_files")
        # ),
        mainPanel(
            titlePanel("Data to Import:"),
            DT::dataTableOutput("import_fixes")
        )
    )
)

server <- function(input, output) {

    imported_fixes <- NULL

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
        DT::datatable(imported_fixes)
    })
}

shinyApp(ui, server)

