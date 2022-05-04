# build_database.R
#
# reads input data and creates a spatial database

#' @import rlang
#' @import dplyr
#' @import sf
#' @importFrom readr locale


# Construct geopackage sqlite database from scratch
# This takes input files describing animals, devices,
# deployments, and the data files, and constructs a geopackage from them
build_database <- function(fix_files,
                           device_files,
                           animal_files,
                           deployment_files,
                           dsn = "~/beastr_db.gpkg",
                           delete_dsn = TRUE,
                           locale = NULL,
                           tz = NULL,
                           ...) {
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
    map( ~ readr::read_delim(.x, locale = locale)) %>%
    reduce(bind_rows) %>%
    distinct() ->
    deployments

  # Write tables into a geopackage (SQLite DB)
  fixes %>%
    st_write(dsn,
             layer = "fixes",
             delete_dsn = delete_dsn)
  devices %>%
    st_write(dsn,
             layer = "devices",
             delete_layer = delete_dsn)

  animals %>%
    st_write(dsn,
             layer = "animals",
             delete_layer = delete_dsn)

  deployments %>%
    st_write(dsn,
             layer = "deployments",
             delete_layer = delete_dsn)

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
