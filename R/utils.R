# utils.R
# utility functions.
# These are used by other functions in this package but not exported


#' Read a list of delimited text files that have a unique ID field.
#' Use this field to pick only distinct entries.
#'
#' @param input_files a single filename or a list of filenames. These are
#' delimited text files that share a column name for the unique identifier
#' @param id_field column/field name for the unique identifier. Defaults to "ID"
#'
read_delims_w_uids <- function(input_files,
                               id_field = ID) {
  input_files %>%
    map(readr::read_delim) %>%
    reduce(bind_rows) %>%
    distinct({{ id_field }}, .keep_all = TRUE)
}
