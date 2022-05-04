
<!-- README.md is generated from README.Rmd. Please edit that file -->

# beastr

<!-- badges: start -->
<!-- badges: end -->

**B**etter **E**nvironment/**A**nimal **S**ensor **T**elemetry
**R**epository

“Better” as in “better than nothing”. There are many other solutions
that are more developed than this, most notably
[Movebank](https://www.movebank.org/)

The goal of beastr is to provide a framework for storing, accessing, and
processing wildlife telemetry data.

## Installation

You can install the package using the
[devtools](https://devtools.r-lib.org/) package

``` r
devtools::install_github('rgzn/beastr')
```

## Example

Build your database:

``` r
library(beastr)
library(sf)

# Use example source data
fix_file = system.file("inst/lotek/33452.txt", package = "beastr")
device_file = system.file("inst/deployment/devices.csv", package = "beastr")
animal_file = system.file("inst/deployment/animals.csv", package = "beastr")
deploy_file = system.file("inst/deployment/deployments.csv", package = "beastr")
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
```

View data linked to animals, rather than sensors:

``` r
library(dplyr)

points = sf::st_read(myDB, layer = "animal_fixes")

points %>% 
  ggplot2::ggplot() + 
  ggplot2::geom_sf(ggplot2::aes(fill = animal_id))
```

## Related Projects

-   ctmmweb \[<https://github.com/ctmm-initiative/ctmmweb>\]
-   collardb \[<https://github.com/kissmygritts/collardb>\]
-   amt \[<https://github.com/jmsigner/amt>\]
-   movebank \[<https://www.movebank.org/>\]

## TODO

-   integrate with amt (use amt tools)
-   integrate with movebank (export/import)
-   add new readers as new devices are used
