library(openxlsx)
library(psrcelmer)
library(dplyr)
library(glue)

dir <- "J:/Projects/Surveys/HHTravel/Survey2023/Data/"
dir_2021 <- "J:/Projects/Surveys/HHTravel/Survey2021/Data/"
#codebook_path <- "J:/Projects/Surveys/HHTravel/Survey2023/Data/PSRC_Combined_Codebook_2023_06122023.xlsx"
codebook_path_2023 <- glue("{dir}PSRC_Combined_Codebook_2023_06122023.xlsx")
codebook_path_2021 <- glue("{dir_2021}Combined_Codebook_2021_Update.xlsx")
sheet_name <- "Value Labels"
out_filename <- "variable_comparisons.xlsx"
wb <- createWorkbook()


dropped_and_added_vars <- function(vars_2023, values_2023, vars_2021, values_2021) {
  # create a list of data four frames comparing the vars and values
  #   from the the input data frames.
  # List elements: new_vars, dropped, vars, new_vals, dropped_vals

  new_variables <- vars_2023 %>%
    anti_join(vars_2021,
              by= 'variable') %>%
    arrange(variable)

  dropped_variables <- vars_2021 %>%
    anti_join(vars_2023, by = "variable") %>%
    select(c('variable')) %>%
    filter(!grepl("weight", variable)) %>%
    arrange(variable)


  new_values <- values_2023 %>%
    anti_join(values_2021, by = c('variable', 'value')) %>%
    anti_join(new_variables, by="variable") %>%
    arrange(variable)

  dropped_values <- values_2021 %>%
    anti_join(values_2023, by = c('variable', 'value')) %>%
    arrange(variable)


  val_comparisons <- list(new_vars = new_variables,
                          dropped_vars = dropped_variables,
                          new_vals = new_values,
                          dropped_vals = dropped_values)

  return(val_comparisons)
}

write_to_xlsx <- function(df, sheet_name, fname, caption = 'Some Text') {
  wb <- loadWorkbook(fname, isUnzipped = FALSE)
  if (!(sheet_name %in% getSheetNames(fname))) {
    addWorksheet(wb, sheetName = sheet_name)
  } else {
    tables <- getTables(wb, sheet_name)
    for (t in tables) {
      removeTable(wb, sheet_name, t)
    }
    num_rows <- 1000
    num_cols <- 2
    empty_df <- data.frame(matrix("", nrow = num_rows, ncol = num_cols))
    writeData(wb, sheet = sheet_name, x = empty_df, colNames = FALSE)
  }
  writeData(wb, sheet = sheet_name, x = caption, startCol = 2)
  if (!is.null(df)) {
    writeDataTable(wb, sheet = sheet_name, x = df)
  }
  saveWorkbook(wb, fname, overwrite = TRUE)
}

#compare the two codebooks (2021 and 2023)
values_2023 <- read.xlsx(codebook_path_2023, 'Value Labels')
values_2021 <- read.xlsx(codebook_path_2021, 'Value_Labels')
vars_2023 <- read.xlsx(codebook_path_2023, 'Variable List') %>%
  rename(yr2023 = '2023', yr2021 = '2021') %>%
  filter(yr2023 == 1) %>%
  select(variable)

vars_2021 <- read.xlsx(codebook_path_2021, 'Variable_List') %>%
  rename(yr2021 = '2021') %>%
  filter(yr2021 == 1) %>%
  select(variable)



l <- dropped_and_added_vars(vars_2023, values_2023, vars_2021, values_2021)
caption <- 'variables added vs. the 2021 codebook'
write_to_xlsx(l$new_vars, 'codebook_added_vars', out_filename, caption)
caption <- 'variables dropped vs. the 2021 codebook'
write_to_xlsx(l$dropped_vars, 'codebook_dropped_vars', out_filename, caption)


# compare codebook-2023 with the columns in the unioned views
sql <- "select distinct c.column_Name as variable \
  , '' as value
  from INFORMATION_SCHEMA.COLUMNS as c\
  where c.TABLE_SCHEMA = 'HHSUrvey' and c.TABLE_NAME in \
  ('v_trips', 'v_households', 'v_persons', 'v_days', 'v_vehicles')"
extant_vars <- get_query(sql, db_name = "Elmer")
l <- dropped_and_added_vars(vars_2023, values_2023, extant_vars, extant_vars)
caption <- 'variables added vs. the unioned views'
write_to_xlsx(l$new_vars, 'views_added_vars', out_filename, caption)
caption <- 'variables dropped vs. the unioned views'
write_to_xlsx(l$dropped_vars, 'views_dropped_vars', out_filename, caption)

# compare codebook-2023 with variables_metadata2
variable_metadata2 <- get_table(db_name = "Elmer", "HHSurvey", "Variable_metadata2") %>%
  mutate(value = "empty") %>%
  select(variable, value)
l <- dropped_and_added_vars(vars_2023, values_2023, variable_metadata2, variable_metadata2)
caption <- 'variables added vs. variable_metadata2'
write_to_xlsx(l$new_vars, 'metadata_added_vars', out_filename, caption)
caption <- 'variables dropped vs. variable_metadata2'
write_to_xlsx(l$dropped_vars, 'metadata_dropped_vars', out_filename, caption)
