
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
## basic example code
```

View data linked to animals, rather than sensors:

``` r
#summary(cars)
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
