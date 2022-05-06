# database.R
#
# reads input data and creates a spatial database




#' Construct geopackage sqlite database from raw data
#' @details This takes input files describing animals, devices,
#' deployments, and the data files, and constructs a geopackage
#' @param fix_files A path, or paths, to files with telemetry fixes.
#' @param device_files A path, or paths, to CSV files containing information
#' about the telemetry devices used. This must include an `ID` column.
#' @param animal_files A path, or paths, to CSV files containing information
#' about the animals on which devices were deployed. This must include an `ID`
#' column.
#' @param deployment_files A path, or paths, to CSV files specifying which
#' devices were deployed on which animals and when. Columns must include:
#' `AnimalID`, `DeviceID`, `In_Service`, and `Out_Service`.
#' @param dsn The path to the database file to be created. Currently must be
#' a .gpkg file.
#' @param delete_dsn If TRUE, remove existing dsn.
#' @param locale Specify time zone using locale object. See [readr::locale()]
#' @param tz Specify time zone using known character string. ie "US/Pacific"
#' @param quiet Boolean passed to `sf::st_write()`
#' @return [build_database()] returns `TRUE`, invisibly.
#'
#' @examples
#' \dontrun{
#'  fix_file = system.file("inst/lotek/PinPoint33452.txt", package = "beastr")
#'  device_file = system.file("inst/deployment/devices.csv", package = "beastr")
#'  animal_file = system.file("inst/deployment/animals.csv", package = "beastr")
#'  deploy_file = system.file("inst/deployment/deployments.csv", package = "beastr")
#'  myDB = paste0(tempdir(check = TRUE), "/", "example.gpkg")
#'  myDB = normalizePath(myDB) # windows?
#'  build_database(fix_files = fix_file,
#'  device_files = device_file,
#'  animal_files = animal_file,
#'  deployment_files = deploy_file,
#'  dsn = myDB,
#'  tz = "US/Pacific")
#'  sf::st_layers(myDB)
#' }
#' @import rlang
#' @import dplyr
#' @import sf
#' @importFrom readr locale
#' @importFrom DBI dbConnect dbExecute dbDisconnect dbWriteTable
#'
#' @export
build_database <- function(fix_files,
                           device_files,
                           animal_files,
                           deployment_files,
                           dsn = "~/beastr_db.gpkg",
                           delete_dsn = TRUE,
                           locale = NULL,
                           tz = NULL,
                           quiet = TRUE) {
  # Set timezone/locale for reading in date time strings
  # NOTE: this does not change the locale in `read_lotek_2_sf`
  # which is always UTC
  if(is_null(locale)) { locale = readr::locale()}
  if(!is_null(tz)) {locale = readr::locale(tz = tz)}

  # Read in fixes, remove duplicates
  fixes = read_lotek(fix_files)

  # Read in device tables:
  devices = read_delims_w_uids(device_files,
                               id_field = ID)

  # Read in animal tables
  animals = read_delims_w_uids(animal_files,
                               id_field = ID)


  #Read in deployment files
  deployment_files %>%
    purrr::map( ~ readr::read_delim(.x, locale = locale)) %>%
    purrr::reduce(bind_rows) %>%
    distinct() ->
    deployments

  # Write tables into a geopackage (SQLite DB)
  fixes %>%
    sf::st_write(dsn,
             layer = "fixes",
             delete_dsn = delete_dsn,
             quiet = quiet)
  devices %>%
    sf::st_write(dsn,
             layer = "devices",
             delete_layer = delete_dsn,
             quiet = quiet)

  animals %>%
    sf::st_write(dsn,
             layer = "animals",
             delete_layer = delete_dsn,
             quiet = quiet)

  deployments %>%
    sf::st_write(dsn,
             layer = "deployments",
             delete_layer = delete_dsn,
             quiet = quiet)

  # Connect to newly created DB:
  con <- DBI::dbConnect(RSQLite::SQLite(), dsn)

  # Create a spatial View in the database
  # A View can be queried like a table, but pulls its data
  # from other tables. This view is for user convenience, so that
  # people can view actual animal data rather than device data.
  # Unfortunately, dplyr does not have a native way to create a view within a
  # table, so I'm doing it with this SQL statement:
  CreateViewSQL =
    "CREATE VIEW \"animal_fixes\" AS SELECT
	deployments.AnimalID as animal_id,
	animals.Species as species,
	animals.Sex as sex,
	animals.AgeClass as age_class,
	fixes.device_id as device_id,
	fixes.Status as fix_status,
	fixes.Sats as sats,
	fixes.HDOP as hdop,
	fixes.`Altitude(m)` as elevation_gps,
	fixes.`Temperature(C)` as temp_c,
	fixes.`Voltage(V)` as voltage,
	fixes.time,
	fixes.geom
FROM
	fixes
LEFT JOIN deployments
ON fixes.device_id = deployments.DeviceID
LEFT JOIN animals
ON deployments.AnimalID = animals.ID
WHERE
time > In_Service AND ( time < Out_Service OR Out_Service ISNULL)"


  # Create the combined data view:
  con %>%
    DBI::dbExecute(CreateViewSQL)

  # Now we need to update the geopackage so that the View is
  # treated as a spatial layer:
  # This is very hacky
  # A proper solution would be to add a trigger updating this from
  # other changes automatically
  # See:
  # https://github.com/qgis/QGIS/issues/25922#issuecomment-495883392
  #
  # Get maximal spatial extents (bounding box) from other spatial layers:
  tbl(con, "gpkg_contents") %>%
    summarise_at(c("min_x", "min_y"), min) %>%
    as_tibble() ->
    bbox_mins
  tbl(con, "gpkg_contents") %>%
    summarise_at(c("max_x", "max_y"), max) %>%
    as_tibble() ->
    bbox_maxs
  tbl(con, "gpkg_contents") %>%
    summarise_at('last_change', max) %>%
    as_tibble() ->
    latest

  tbl(con,"gpkg_contents") %>%
    filter(table_name == "fixes") %>%
    select(srs_id) %>%
    as_tibble() ->
    srs

  # A row of data to be added to the gpkg_contents table
  view_contents = data.frame(table_name = "animal_fixes",
                             data_type = "features",
                             identifier = "animal_fixes",
                             description = "",
                             last_change = latest[[1]],
                             min_x = bbox_mins$min_x,
                             min_y = bbox_mins$min_y,
                             max_x = bbox_maxs$max_x,
                             max_y = bbox_maxs$max_y,
                             srs_id = srs)

  # A row of data to be added to the gpkg_geometry_columns table
  view_geometry_columns = data.frame(table_name = "animal_fixes",
                                     column_name = "geom",
                                     geometry_type_name = "POINT",
                                     srs_id = srs,
                                     z = 0,
                                     m = 0 )
  con %>%
    DBI::dbWriteTable("gpkg_contents",
                 append = TRUE,
                 view_contents)
  con %>%
    DBI::dbWriteTable("gpkg_geometry_columns",
                 append = TRUE,
                 view_geometry_columns)

  DBI::dbDisconnect(con)
}

#' Add new records to existing database
#'
#' @inheritParams build_database
#' @return [append_database()] returns `TRUE`, invisibly.
#' @import rlang
#' @import dplyr
#' @export
append_database <- function(dsn,
                            fix_files = NULL,
                            device_files = NULL,
                            animal_files = NULL,
                            deployment_files = NULL) {

  if(!is_null(device_files)) {
    read_delims_w_uids(device_files, id_field = ID) %>%
      append_layer(dsn = dsn, layer = "devices")
  }
  if(!is_null(animal_files)) {
    read_delims_w_uids(animal_files, id_field = ID) %>%
      append_layer(dsn = dsn, layer = "animals")
  }
  if(!is_null(deployment_files)) {

      append_layer(dsn = dsn, layer = "devices")
  }
  if(!is_null(fix_files)){
    read_lotek(fix_files) %>%
      append_layer(dsn = dsn, layer = "fixes")
  }
}



#' Insert rows into a spatial database
#'
#' The `append_layer()` method assumes the data source already has a layer
#' of the same format as the new data. This can work with either spatial or
#' non-spatial data. It use `sf::st_write()` instead of `DBI::dbAppendTable()`
#' in order to handle spatial data.
#' @param data a tibble or data frame to write to the database. The column names
#' must be consistent with those in the target layer.
#' @param dsn data source name. Typically a path to a geopackage.
#' @param layer layer name to append.
#' @param id_fields names of field on which to join the new data. These fields
#' determine whether each row is unique using`dplyr::anti_join()`
#' @importFrom dplyr anti_join
#' @importFrom sf st_read st_write
#' @export
append_layer <- function(data,
                         dsn,
                         layer,
                         id_fields = NULL) {

  old_data = sf::st_read(dsn,
                         layer = layer,
                         as_tibble = TRUE)
  # Cannot perform dplyr unions on 2 spatial
  # dataframes, so convert one to non-spatial:
  if("sf" %in% class(old_data)) {
    old_data = sf::st_drop_geometry(old_data)
  }
  data %>%
    dplyr::anti_join(old_data, by = id_fields) ->
    new_data

  sf::st_write(new_data,
               dsn = dsn,
               layer = layer,
               append = TRUE)
}
