library(odbc)
library(DBI)


data_dir <- 'J:\\Projects\\Surveys\\HHTravel\\Survey2025\\Data\\delivery_20250816\\Unweighted_Dataset\\07_Unweighted_Dataset\\UnweightedDataset_2025-08-15'


conn <- dbConnect(odbc::odbc(),
                              driver = "ODBC Driver 17 for SQL Server",
                              server = "SQLserver",
                              database = "HouseholdTravelSurvey2025",
                              trusted_connection = "yes"
) 

import_file <- function(conn, fname) {
  tryCatch({
    fpath <- paste0(data_dir, '\\', fname)
    tbl <- readRDS(fpath)
    df <- as.data.frame(tbl) 
    tblname <- gsub('.RDS', '', fname)
    table_id <- Id(schema = "dbo", table = tblname)
    dbWriteTable(conn = conn, name = table_id, value = df)
  }, error = function(e) {
    print(paste("An error happened in import_file:", fname))
    stop(e)
  })
}


import_file(conn, 'ex_day.RDS')
import_file(conn, 'ex_hh.RDS')
import_file(conn, 'ex_location.RDS')
import_file(conn, 'ex_person.RDS')
import_file(conn, 'ex_trip_linked.RDS')
import_file(conn, 'ex_trip_unlinked.RDS')
import_file(conn, 'ex_vehicle.RDS')

dbDisconnect(conn)