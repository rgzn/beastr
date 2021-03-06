# read_lotek.R
# Functions to read raw data into R

#' @import rlang
#' @import dplyr
#' @import sf
#' @importFrom readr read_fwf
#' @importFrom purrr pluck map map_chr map_dbl reduce
#' @import lubridate
#' @importFrom stringr str_detect str_replace_all str_extract
#' @docType package
#' @name packagename
NULL


#' Read Lotek gps txt files into a spatial dataframe.
#'
#' This function takes one or more lotek txt files and turns them
#' into an sf collection of points. If there are multiple versions
#' of the same fix record, duplicates will be removed by default.
#' Only the duplicate from the most recent file is kept.
#'
#' @param files Input files. This can be a path to a single file,
#' a character vector of paths to multiple files, or a list
#' of paths to multiple files.
#'
#' @param ids the device id #s. by default this comes from the filename.
#' Note that shiny file input will change filenames, so this field must be used
#' in that case.
#'
#' @param remove_duplicates if `FALSE`, duplicate records are included
#' in the output
#'
#' @param input_crs reference system used for interpreting coords from file
#' @param output_crs reference system for output spatial df
#' @param tz timezone string to convert timezone processing
#' @param show_col_types Passed to readr functions. Useful for debugging.
#'
#' @examples
#' points = read_lotek(system.file("lotek/PinPoint33452.txt", package="beastr"))
#' summary(points)
#'
#' @importFrom purrr pluck map map_chr map_dbl reduce
#' @export
read_lotek <- function(files,
                       ids = NULL,
                       remove_duplicates = TRUE,
                       show_col_types = FALSE) {
  #id_field <- rlang::enquo(id_field)

  if(is_null(ids)){
    files %>%
      purrr::map(~ read_lotek_2_sf(
        filename = .x,
        id = NULL,
        show_col_types = show_col_types )) %>%
      purrr::reduce(bind_rows) ->
      fixes
  } else {
    purrr::map2(files,
                ids,
                ~ read_lotek_2_sf(filename = .x,
                                  id = .y,
                                  show_col_types = show_col_types )) %>%
      purrr::reduce(bind_rows) ->
      fixes
  }
  if (remove_duplicates) {
    fixes %>%
      group_by(device_id, Index) %>%
      arrange(desc(Ingest_Time)) %>%
      filter(row_number() == 1) %>%
      ungroup()
  }
}


#' Read single Lotek gps txt file into a spatial dataframe.
#'
#' This function takes a fixed-width delimited lotek txt file and turns it
#' into an sf collection of points.
#'
#' @param filename a lotek fixed width text file listing fixes from a collar
#' the filename is assumed to be in the standard lotek format, with device id.
#'
#'
#' @param id the device id #. by default this comes from the filename
#' @param input_crs reference system used for interpreting coords from file
#' @param output_crs reference system for output spatial df
#' @param tz timezone string to convert timezone processing
#'``
#' @export
read_lotek_2_sf <- function(filename,
                            #id_field = DeviceID,
                            id = NULL,
                            input_crs = 4326,
                            output_crs = 32611,
                            tz = "UTC",
                            ingest_time = NA,
                            show_col_types = FALSE) {

  # id_field = rlang::enquo(id_field)


  # Get device ID from filename if not given:
  if (is.null(id)) {
    filename %>%
      basename() %>%
      stringr::str_extract("[0-9]+") ->
    id
  }

  # Get the date of modification.
  # This is useful if 2 files have overlapping data.
  # Due to Lotek's use of "swift" fixes,
  # (Computing GPS points from RINEX using an postprocessing from
  # an online service) PinPoint data files generated from the same
  # observation file from the same collar may not entirely agree on
  # coordinates, altitude, DOP, etc.
  # Including the modification date can simplify this by always using the
  # more recent acquisition

  # Originally had this set to use filename,
  # but discovered sometimes filename is totally wrong(!!)
  # Use filename if date is present:
  # filename %>%
  #   basename() %>%
  #   str_extract("\\d{4}-\\d{2}-\\d{2} \\d{2}-\\d{2}-\\d{2}") %>%
  #   as_datetime() ->
  #   ingest_time
  #

  # Otherwise use modification_time from system:
  if (is.na(ingest_time)) {
    fs::file_info(filename) %>%
      dplyr::pull(modification_time) ->
    ingest_time
  }

  # Not sure what this does, but nate does it so i assume it's useful -jw
  filename <- paste(filename, sep = "", collapse = " ")

  # Get column names (is there an automatic way to do this with read_fwf?)
  # 20220324: submitted issue to readr about this:
  # https://github.com/tidyverse/readr/issues/1393
  # -jw
  readr::read_fwf(filename,
                  n_max = 1,
                  show_col_types = show_col_types) %>%
    as.character() ->
  column_names
  # # Get columnar data
  df <- readr::read_fwf(filename, skip = 1,
                        col_type = "iccctctdddddddd",
                        show_col_types = show_col_types)
  # # Name columns
  names(df) <- column_names

  # Alternate strategy, breaks due to Lotek's inconsistent use of whitespace in
  #   data columns:
  # df <- read_table(filename, col_type = "iccctctdddddddd" )

  # Add in device id:
  # Create a column for the individual Collar ID
  df %>%
    dplyr::mutate(device_id = as.character(id)) %>%
    dplyr::select(device_id,
                  everything()) ->
  df

  # Add in pinpoint file modification time:
  df %>%
    mutate(Ingest_Time = ingest_time) ->
  df

  # Make this thing spatial
  df %>%
    sf::st_as_sf(
      coords = c("Longitude", "Latitude"),
      crs = input_crs,
      na.fail = FALSE
    ) ->
  df
  # Make DateTime columns for sick temporal analyses, note raw time is in UTC
  # Datetime object stores posixct time, and here we set it to display in
  #   local time using `lubridate::with_tz`
  # Do we want RTC (on board clock) or FIX (gps clock)?
  df %>%
    mutate(time = as_datetime(`RTC-date`, format = "%y/%m/%d", tz = "UTC") +
      `RTC-time`) %>%
    mutate(time = with_tz(time, tzone = tz)) ->
  df


  # Local Time
  # This is so ugly, ideally we will only do this on writing output data, or not
  #   at all, because timezone is included in the output for standard datetime
  #   objects
  # df %>%
  #   mutate(Local_Time = as.character(time)) ->
  #   df

  # Transform to output CRS and return
  df %>%
    sf::st_transform(output_crs)
}


#' Read single lotek activity 'csv' with header
#'
#' @param filename A path to a single lotek activity text file.
#' This should point to a lotek activity .csv files, which are
#' not really true CSVs.
#' @param show_col_types Passed on to [`readr`] functions. Useful for debugging.
read_lotek_activity_txt <- function(filename,
                                    show_col_types = FALSE) {
  # see ?readr::parse_datetime or base::strptime
  datetime_format = "%m/%d/%Y %I:%M:%S %p"
  gmt_locale = readr::locale(tz = "GMT")

  # Get header info
  # first 3 lines are colon delimitted text with
  # device info
  readr::read_delim(filename,
                    delim = ": ",
                    n_max = 3,
                    col_names = FALSE,
                    show_col_types = show_col_types) %>%
    tidyr::pivot_wider(names_from = X1, values_from = X2) ->
    header

  # Get activity data
  # The 5th line of the file onwards is a CSV
  # (With field names in the 5th line)
  readr::read_delim(filename,
                    delim = ",",
                    skip = 4,
                    show_col_types = show_col_types) %>%
    mutate(time = readr::parse_datetime(`GMT Time`,
                                        format = datetime_format,
                                        locale = gmt_locale),
           .keep = "unused") %>%
    select(time, everything()) ->
    data

  data %>%
    mutate(device_id = header$`Product ID`) %>%
    select(device_id, everything())
}

#' Read one or more lotek activity text files
#'
#' If the same record is contained in multiple files, duplicates are removed.
#' This happens when a device has multiple downloads with overlapping timespans.
#' Note that this data is not spatial, but may be linked to corresponding
#' spatial data through the `device_id` and `time`.
#'
#' @param files File paths, either a single file path or a list/vector of
#' multiple paths. These should point to lotek activity .csv files, which are
#' not really true CSVs.
#' @examples
#' activity_files = system.file("lotek/activity.csv", package="beastr")
#' activity = read_lotek_activity(activity_files)
#' @export
read_lotek_activity <- function(files) {
  files %>%
    purrr::map(read_lotek_activity_txt) %>%
    purrr::reduce(bind_rows) %>%
    distinct()
}

#' Extract the id info from a lotek filename
#'
#' @param path path or filename for a lotek data file.
#' @return characters of the device id
#'
#' @export
get_id_from_filename<- function(path) {
  path %>%
    basename() %>%
    stringr::str_extract("[0-9]+")
}
