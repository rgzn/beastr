
<!-- README.md is generated from README.Rmd. Please edit that file -->

# beastr

<!-- badges: start -->
<!-- badges: end -->

**B**etter **E**nvironment/**A**nimal **S**ensor **T**elemetry
**R**epository

“Better” as in “better than nothing”. There are many other solutions
that are more developed than this, most notably
[Movebank](https://www.movebank.org/). Also I’m just really bad at
naming things.

The goal of beastr is to provide a framework for storing, accessing, and
processing wildlife telemetry data.

## Installation

You can install the package using the
[devtools](https://devtools.r-lib.org/) package

``` r
devtools::install_github('rgzn/beastr')
```

## Details

For more details see the articles/vignettes on this package. In
particular, the [Introduction](docs/articles/a_Introduction.html) will
explain what data this deals with and why.

## Example

Build your database:

``` r
library(beastr, quietly = TRUE)
library(sf, quietly = TRUE)

# Use example source data
fix_file = system.file("lotek/PinPoint33452.txt", package = "beastr")
device_file = system.file("devices/collars.csv", package = "beastr")
animal_file = system.file("animals/critters.csv", package = "beastr")
deploy_file = system.file("deployments/deployments.csv", package = "beastr")
myDB = paste0(tempdir(check = TRUE), "/", "example.gpkg")

# Build a database
build_database(fix_files = fix_file,
               device_files = device_file,
               animal_files = animal_file,
               deployment_files = deploy_file,
               dsn = myDB,
               tz = "US/Pacific")

# What layers are in there?
sf::st_layers(myDB)
#> Driver: GPKG 
#> Available layers:
#>     layer_name geometry_type features fields crs_name
#> 1        fixes         Point      468     14    32611
#> 2 animal_fixes         Point      462     12    32611
#> 3      devices            NA       33      7     <NA>
#> 4      animals            NA        4      5     <NA>
#> 5  deployments            NA       20      6     <NA>
```

View data linked to animals, rather than sensors:

``` r
library(dplyr, quietly = TRUE)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(ggplot2, quietly = TRUE)

points = sf::st_read(myDB, layer = "animal_fixes")
#> Reading layer `animal_fixes' from data source 
#>   `/private/var/folders/q2/53ffh3110_5fqqp7tmq2s5th0000gn/T/RtmpEWw7vr/example.gpkg' 
#>   using driver `GPKG'
#> Simple feature collection with 462 features and 12 fields (with 160 geometries empty)
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 261780.2 ymin: 4173114 xmax: 267257.4 ymax: 4178607
#> CRS:           32611

points %>% 
  ggplot2::ggplot() + 
  ggplot2::geom_sf(ggplot2::aes(fill = animal_id))
```

<img src="man/figures/README-unnamed-chunk-3-1.png" width="100%" />

## Related Projects

-   ctmmweb \[<https://github.com/ctmm-initiative/ctmmweb>\]
-   collardb \[<https://github.com/kissmygritts/collardb>\]
-   amt \[<https://github.com/jmsigner/amt>\]
-   movebank \[<https://www.movebank.org/>\]

## TODO

-   integrate with `{amt}` (use amt tools)
-   integrate with movebank (export/import)
-   add new readers as new devices are used
-   use `{golem}` for the shiny app stuff
