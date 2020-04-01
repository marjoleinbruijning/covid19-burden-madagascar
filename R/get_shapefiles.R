# ------------------------------------------------------------------------------------------------ #
#' Write out simplified shapefiles for cluster                  
# ------------------------------------------------------------------------------------------------ #

library(rgdal)
library(malariaAtlas)
library(rmapshaper)

# metadata
metadata <- read.csv("wp_data/Africa_1km_Age_structures_2020/Demographic_data_organisation_per country_AFRICA.csv")
iso_codes <- data.frame(iso = metadata$ISO_3, country = metadata$name_english)
write.csv(iso_codes, "output/iso_codes.csv", row.names = FALSE)

# Country level
countries <- getShp(ISO = metadata$ISO_3)
countries@data <- data.frame(apply(countries@data, 2, iconv, from ='utf-8', to ='ascii', sub=''))
countries <- ms_simplify(countries, keep_shapes = TRUE)
writeOGR(countries, dsn = "shapefiles", layer = "country", 
         driver = "ESRI Shapefile", overwrite_layer = TRUE)

# Admin 1
admin1 <- getShp(ISO = metadata$ISO_3, admin_level = "admin1")
admin1@data <- data.frame(apply(admin1@data, 2, iconv, from ='utf-8', to ='ascii', sub=''))
admin1 <- ms_simplify(admin1, keep_shapes = TRUE)
writeOGR(admin1, dsn = "shapefiles", layer = "admin1", 
         driver = "ESRI Shapefile", overwrite_layer = TRUE)

# Admin 2
admin2 <- getShp(ISO = metadata$ISO_3, admin_level = "admin2")
admin2@data <- data.frame(apply(admin2@data, 2, iconv, from ='utf-8', to ='ascii', sub=''))
admin2 <- ms_simplify(admin2, keep_shapes = TRUE)
writeOGR(admin2, dsn = "shapefiles", layer = "admin2", 
         driver = "ESRI Shapefile", overwrite_layer = TRUE)

# Admin 3
admin3 <- getShp(ISO = metadata$ISO_3, admin_level = "admin3")
admin3@data <- data.frame(apply(admin3@data, 2, iconv, from ='utf-8', to ='ascii', sub=''))
writeOGR(admin3, dsn = "shapefiles", layer = "admin3", 
         driver = "ESRI Shapefile", overwrite_layer = TRUE)
