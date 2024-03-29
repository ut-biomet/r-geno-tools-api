#
# This is a Plumber API. In RStudio 1.2 or newer you can run the API by
# clicking the 'Run API' button above.
#
# In RStudio 1.1 or older, see the Plumber documentation for details
# on running the API.
#
# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#


# Initialisation ----
cat(as.character(Sys.time()), "-",
    "Start Plumber API using 'plumber v'",
    as.character(packageVersion("plumber")), "\n")

cat(as.character(Sys.time()), "-",
    "Load `plumber` package","\n")
library(plumber)

# load r-geno-tools-engine functions
cat(as.character(Sys.time()), "-",
    "Load `r-geno-tools-engine`","\n")
sapply(list.files("r-geno-tools-engine/src/",
                  pattern = "\\.R$", # all files ending by ".R"
                  full.names = TRUE),
       source)

# load r-geno-tools-api functions
cat(as.character(Sys.time()), "-",
    "Load `r-geno-tools-api`'s functions","\n")
sapply(list.files("src/",
                  pattern = "\\.R$", # all files ending by ".R"
                  full.names = TRUE),
       source)

# create initialization logger
initLog <- Logger$new("r-geno-tools-api-INIT")


# Define the default png serializer for the images
my_serializer_png <- serializer_png(width = 40,
                                    height = 30,
                                    units = 'cm',
                                    res = 177,
                                    pointsize = 20)

# create new plumber router
initLog$log("create new router")
genoApi <- pr()





# Set api description ----
initLog$log("Set api description")
genoApi$setApiSpec(
  function(spec) {
    spec$info <- list(
      title = "GWAS API",
      description = "REST API for GWAS analysis",
      # termsOfService = "",
      contact = list(name = "Laboratory of Biometry and Bioinformatics, Hiroyoshi Iwata",
                     email = "iwata@ut-biomet.org"),
      license = list(name = "MIT",
                     url = "https://opensource.org/licenses/MIT"),
      version = "0.0.1"
    )

    spec$tags <- list(
      list(name = "Utils",
           description = "Endpoints for checking the API"),
      list(name = "GWAS",
           description = "Endpoints related to gwas analysis"),
      list(name = "Plots",
           description = "Endpoints related to plots drawn from a GWAS model"),
      list(name = "Relationship matrix",
           description = "Endpoints related to relationship matrices"),
      list(name = "Crossing Simulation",
           description = "Endpoints related to crossing simulation"),
      list(name = "Progenies blups calculation",
           description = "Endpoints related to progenies' blup variance and expected values")
      )
    spec
  }
)


# Set filters ----
initLog$log("Set api filters")
filterLogger <- Logger$new("r-geno-tools-api-REQUESTS")
# Log some information about the incoming requests
genoApi <- genoApi %>%
  pr_filter("logger",
            function(req){
              logger <- filterLogger
              logger$log(req$REQUEST_METHOD, req$PATH_INFO, "-",
                         req$HTTP_USER_AGENT, "@", req$REMOTE_ADDR)
              plumber::forward()
            })

# Redirect request sent to `/manplot` to `/manplot.html`
genoApi <- genoApi %>%
  pr_filter("redirect manplot",
            function(req){
              if (identical(req$PATH_INFO, "/manplot")) {
                logger <- filterLogger
                logger$log("Request to /manplot detected, redirect to /manplot.html")
                req$PATH_INFO <- "/manplot.html"
              }
              plumber::forward()
            })


# Set endpoints ----
initLog$log("Set api endpoints")

## Utils endpoints----
initLog$log("Set `/echo`")
### /echo ----
genoApi <- genoApi %>% pr_get(
  path = "/echo",
  tags = "Utils",
  comments = "Echo back the input",
  params = echo_params,
  handler = echo_handler,
  serializer = serializer_unboxed_json()
)


### /version ----
initLog$log("Set `/version`")
genoApi <- genoApi %>% pr_get(
  path = "/version",
  tags = "Utils",
  comments = "Give information about current API version",
  params = version_params,
  handler = version_handler,
  serializer = serializer_unboxed_json()
)





## GWAS endpoints ----
### /gwas ----
initLog$log("Set `/gwas`")
genoApi <- genoApi %>% pr_post(
  path = "/gwas",
  tags = "GWAS",
  comments = "Fit a GWAS model. This endpoint take Urls of geno and pheno data (and values of other GWAS parameters) and write an a json file to the give Url using a PUT request. It had been disign to work with amazon S3 services.",
  params = gwas_params,
  handler = gwas_handler,
  serializer = serializer_unboxed_json()
)



### /adjustedResults ----
initLog$log("Set `/adjustedResults`")
genoApi <- genoApi %>% pr_get(
  path = "/adjustedResults",
  tags = "GWAS",
  comments = "Adjusted results. This endpoint calculate the adjusted p-values of the gwas analysis and return all the results or only the significant adjusted p-value. The results are return in json format.",
  params = adjustedResults_params,
  handler = adjustedResults_handler,
  serializer = serializer_unboxed_json()
)



## Plot endpoints ----
### /manplot ----
initLog$log("Set `/manplot`")
genoApi <- genoApi %>% pr_get(
  path = "/manplot",
  tags = "Plots",
  comments = "Identical to `/manplot.html`",
  params = manplot_params,
  handler = function(){
    "You should not be able to see that, this endpoint have been deprecated."
  },
  serializer = serializer_htmlwidget()
)

### /manplot.html ----
initLog$log("Set `/manplot.html`")
genoApi <- genoApi %>% pr_get(
  path = "/manplot.html",
  tags = "Plots",
  comments = "Draw a Manhattan plot. This endpoint return the html code of a plotly interactive graph. By default only the 3000 points with the lowest p-values are display on the graph.",
  params = manplot_params,
  handler = create_manplot_handler(interactive = TRUE),
  serializer = serializer_htmlwidget()
)


### /manplot.png ----
initLog$log("Set `/manplot.png`")
genoApi <- genoApi %>% pr_get(
  path = "/manplot.png",
  tags = "Plots",
  comments = "Draw a Manhattan plot. This endpoint return png Image of the graph. By default all the points are display on the graph.",
  params = manplot_params,
  handler = create_manplot_handler(interactive = FALSE),
  serializer = my_serializer_png
)


### /LDplot ----
initLog$log("Set `/LDplot`")
genoApi <- genoApi %>% pr_get(
  path = "/LDplot",
  tags = "Plots",
  comments = "Draw a LD plot. This endpoint return a png image.",
  params = LDplot_params,
  handler = LDplot_handler,
  serializer = my_serializer_png
)



### /pedNetwork ----
initLog$log("Set `/pedNetwork`")
genoApi <- genoApi %>% pr_get(
  path = "/pedNetwork",
  tags = "Plots",
  comments = "Draw interactive pedigree network",
  params = pedNetwork_params,
  handler = pedNetwork_handler,
  serializer = serializer_htmlwidget()
)


### /relmat-ped ----
initLog$log("Set `/relmat-ped`")
genoApi <- genoApi %>% pr_post(
  path = "/relmat-ped",
  tags = "Relationship matrix",
  comments = "Calculate a pedigree relationship matrix. This endpoint take Urls of a pedigree file and write an a json file to the given Url using a PUT request. It had been disign to work with amazon S3 services.",
  params = relmatped_params,
  handler = relmatped_handler,
  serializer = serializer_unboxed_json()
)

### /relmat-geno ----
initLog$log("Set `/relmat-geno`")
genoApi <- genoApi %>% pr_post(
  path = "/relmat-geno",
  tags = "Relationship matrix",
  comments = "Calculate a genomic relationship matrix. This endpoint take Urls of a genetic file and write an a json file to the given Url using a PUT request. It had been disign to work with amazon S3 services.",
  params = relmatgeno_params,
  handler = relmatgeno_handler,
  serializer = serializer_unboxed_json()
)

### /relmat-combined ----
initLog$log("Set `/relmat-combined`")
genoApi <- genoApi %>% pr_post(
  path = "/relmat-combined",
  tags = "Relationship matrix",
  comments = "Calculate a combined relationship matrix. This endpoint take Urls of a genetic relationship file and a pedigree relationship file and write an a json file to the given Url using a PUT request. It had been disign to work with amazon S3 services.",
  params = relmatCombined_params,
  handler = relmatCombined_handler,
  serializer = serializer_unboxed_json()
)

### /relmat-heatmap.html ----
initLog$log("Set `/relmat-heatmap.html`")
genoApi <- genoApi %>% pr_get(
  path = "/relmat-heatmap.html",
  tags = "Plots",
  comments = "Draw a heatmap of a relationship matrix.",
  params = relmatHeatmap_params,
  handler = create_relmatHeatmap_handler(interactive = TRUE),
  serializer = serializer_htmlwidget()
)

### /relmat-heatmap.png ----
initLog$log("Set `/relmat-heatmap.png`")
genoApi <- genoApi %>% pr_get(
  path = "/relmat-heatmap.png",
  tags = "Plots",
  comments = "Draw a heatmap of a relationship matrix.",
  params = relmatHeatmap_params,
  handler = create_relmatHeatmap_handler(interactive = FALSE),
  serializer = my_serializer_png
)


### /crossing-simulation ----
initLog$log("Set `/crossing-simulation`")
genoApi <- genoApi %>% pr_post(
  path = "/crossing-simulation",
  tags = "Crossing Simulation",
  comments = "Simulate genotypes of progenies of given parents",
  params = crossingSim_params,
  handler = crossingSim_handler)


### /progenyBlupCalc
initLog$log("Set `/progenyBlupCalc`")
genoApi <- genoApi %>% pr_post(
  path = "/progenyBlupCalc",
  tags = "Progenies blups calculation",
  comments =  paste(
    "Estimate the BLUPs' expected value and variance of the progenies of a",
    "given crosses specifyed in the crossing table."
  ),
  params = progenyBlupCalc_params,
  handler = progenyBlupCalc_handler)


### /progenyBlup-plot ----
initLog$log("Set `/progenyBlup-plot`")
genoApi <- genoApi %>% pr_get(
  path = "/progenyBlup-plot",
  tags = "Plots",
  comments =   paste(
    "Draw a plot of the progenies BLUPs' expected values with error bars.",
    "X axis is the crosses, and Y axis the blups. The points are located",
    "at the expected value and the error bar length is the standard deviation."
  ),
  params = progenyBlupPlot_params,
  handler = progenyBlupPlot_handler,
  serializer = serializer_htmlwidget())
