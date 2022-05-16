# filter.R
#
# data filtering functions
# These functions help remove bad data using various metrics



#' Compute speed from gps telemetry data
#'
#' @param df
#' Object must also have a time column
#' returns a vector,  to be used with dplyr::mutate
speed <- function(df,
                  id_field = animal_id,
                  leadlagfun = dplyr::lead,
                  time_field = time,
                  geom_field = geom
                  #, diff_cols = FALSE,
) {
  time_field = enquo(time_field)
  geom_field = enquo(geom_field)
  id_field = enquo(id_field)

  df %>%
    group_by(!!id_field) %>%
    group_by(st_is_empty(!!geom_field)) %>%
    mutate(dT = leadlagfun(!!time_field, order_by=!!time_field) - !!time_field,
           dG = st_distance(!!geom_field,
                            leadlagfun(!!geom_field, order_by=!!time_field),
                            by_element = TRUE)) %>%
    transmute(speed = abs(as.numeric(dG )/ as.numeric(dT))) %>%
    st_drop_geometry() %>%
    ungroup() %>%
    select(speed) ->
    df
  #return(df)
  return(pull(df, 1))

  # if(!diff_cols) {
  #   df %>%
  #     dplyr::select(-dG, -dT) ->
  #     df
  # }
  # return(df)
}

# Returns full dataframe with added speed column
# speed is the min? of the lead speed and lag speed
# (computed from the previous point in time or the
# next point in time)
get_speed <- function(df,
                      id_field = animal_id,
                      time_field = time,
                      geom_field = geom) {
  time_field = enquo(time_field)
  geom_field = enquo(geom_field)
  id_field = enquo(id_field)

  df %>%
    mutate(speed_lead = speed(.,
                              id_field = !!id_field,
                              geom_field = !!geom_field,
                              leadlagfun = dplyr::lead)) %>%
    mutate(speed_lag = speed(.,
                             id_field = !!id_field,
                             geom_field = !!geom_field,
                             leadlagfun = dplyr::lag)) %>%
    rowwise() %>%
    mutate(speed = pmin(speed_lead,
                        speed_lag,
                        na.rm = TRUE)) %>%
    select(-speed_lag, -speed_lead)
}

filter_speed <- function(df,
                         max_speed = Inf,
                         min_speed = -Inf,
                         time_field = time,
                         geom_field = geom,
                         speed_col = FALSE,
                         rm.na = FALSE) {
  time_field = enquo(time_field)
  geom_field = enquo(geom_field)
  df %>%
    get_speed(time_field = !!time_field,
              geom_field = !!geom_field ,
              diff_cols = FALSE) %>%
    filter(!rm.na & is.na(speed) |
             speed < max_speed & speed > min_speed) ->
    df

  if(!speed_col) {
    df %>%
      dplyr::select(-speed) ->
      df
  }

  return(df)
}



#' Add elevation column for an sf POINT collection.
#'
#' @param df an SFC of POINT geometries
#' @param dem_src path to Digital Elevation Model file. This must
#' be a raster file, usually a .tif
#' @param units TODO: currently assumes all units are meters.
#' @examples
#' \dontrun{
#' dem_src = "USGS_13_n38w120_20210701.tif"
#' myDB = system.file("db/telemetry.gpkg", package = "beastr")
#' }
#' @importFrom dplyr mutate
#' @importFrom stars read_stars st_extract
#' @importFrom sf st_read st_coordinates st_transform st_crs
#' @export
get_elevation_dem <- function(df,
                              dem_src,
                              units = "meters") {
  dem <- stars::read_stars(dem_src, proxy = TRUE)

  # Dev Notes:
  # Tried using elevatr package,
  # but their integration with sf is marginal
  # Would be better to write our own version of
  # elevatr::get_epqs
  #
  # Now using our own raster layer
  # disadvantage: must have raster layer
  # advantage: much much faster than http requests
  #
  # Strange issue in stars::st_extract:
  # the elevation column is added, but the display name
  # remains the name of the layer from the tif ???


  # elevation_layer <- names(dem)[1]   # previously used in solving the list/unlist problem

  # Data points and DEM must be in the same CRS
  # record them so we can convert back
  dem_crs <- sf::st_crs(dem)
  input_crs <- sf::st_crs(df)

  # NOTE: The mutate/unlist step is the solution to a very hard to spot bug
  # Without it, the elevations from st_extract are in a list
  # Printing the data.frame will make it look like a normal vector column,
  # but it won't be usable as such! -jw

  df %>%
    sf::st_transform(dem_crs) %>%
    mutate(elevation_list =
             stars::st_extract(dem, at = sf::st_coordinates(.))) %>%
    mutate(elevation_dem = unlist(elevation_list), .keep = "unused") %>%
    sf::st_transform(input_crs)
}




#' Get difference between DEM raster and elevation column in an sfc
#'
#' @param df spatial datagram with elevation column
#' @param dem_src path to Digital Elevation Model file. This must
#' be a raster file, usually a .tif
#' @param elev_field Existing elevation column in `df`
#' @param geom_field name of geometry column in df
#' @param abs If true, use absolute difference
#' @importFrom dplyr mutate
#' @importFrom stars read_stars st_extract
#' @importFrom sf st_read st_coordinates st_transform st_crs
#' @export
get_elevation_difference <- function(df,
                                     dem_src,
                                     elev_field = elevation_gps,
                                     geom_field = geom,
                                     abs = TRUE) {
  elev_field = enquo(elev_field)

  df %>%
    get_elevation_dem(dem_src = dem_src) %>%
    dplyr::mutate(elevation_dif = !!elev_field - elevation_dem) ->
    df

  if(abs) {
    df %>%
      mutate(elevation_df = abs(elevation_dif)) ->
      df
  }

  return(df)

}
