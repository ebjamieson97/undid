/*------------------------------------*/
/*undid_stage_two*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-24 */
/*------------------------------------*/
cap program drop undid_stage_two
program define undid_stage_two
    version 16
    syntax, empty_diff_filepath(string) silo_name(string) ///
            time_column(varname) outcome_column(varname) silo_date_format(string) ///
            [consider_covariates(int 1) filepath(string)]

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------- PART ONE: Checks ------------------------------------ // 
    // ---------------------------------------------------------------------------------------- // 

    // Define undid variables
    local UNDID_DATE_FORMATS "ddmonyyyy yyyym00 yyyy/mm/dd yyyy-mm-dd yyyymmdd yyyy/dd/mm yyyy-dd-mm yyyyddmm dd/mm/yyyy dd-mm-yyyy ddmmyyyy mm/dd/yyyy mm-dd-yyyy mmddyyyy yyyy"
    local expected_common "silo_name treat common_treatment_time start_time end_time weights diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq"
    local expected_staggered "silo_name gvar treat diff_times gt RI start_time end_time diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq"

    // Check consider_covariates
    if `consider_covariates' < 0 | `consider_covariates' > 1 {
        di as result "Error: consider_covariates must be set to 0 (false) or to 1 (true)."
        exit 2
    }

    // If no filepath given, use tempdir, construct output paths for filled_diff and trends_data
    if "`filepath'" == "" {
        local filepath "`c(tmpdir)'"
    }
    local fullpath_diff "`filepath'/filled_diff_df_`silo_name'.csv"
    local fullpath_diff = subinstr("`fullpath_diff'", "\", "/", .)
    local fullpath_diff = subinstr("`fullpath_diff'", "//", "/", .)
    local fullpath_diff = subinstr("`fullpath_diff'", "//", "/", .)
    local fullpath_trends "`filepath'/trends_data_`silo_name'.csv"
    local fullpath_trends = subinstr("`fullpath_trends'", "\", "/", .)
    local fullpath_trends = subinstr("`fullpath_trends'", "//", "/", .)
    local fullpath_trends = subinstr("`fullpath_trends'", "//", "/", .)

    // Make sure the empty_diff_filepath actually goes to a CSV file
    if substr("`empty_diff_filepath'", -4, .) != ".csv" {
        di as error "Error: empty_diff_filepath should end in .csv"
        exit 3
    }

    // Check that the silo_date_format is a valid option
    local silo_date_format = lower("`silo_date_format'")
    local found_date_format = 0
    foreach format in `UNDID_DATE_FORMATS' {
        if "`silo_date_format'" == "`format'" {
            local found_date_format = 1
            continue, break
        }
    }
    if `found_date_format' == 0 {
        di as error "Error: The date_format (`silo_date_format') is not recognized. Must be one of: `UNDID_DATE_FORMATS'."
        exit 4
    }

    // Read in empty_diff, check that silo_name exists and that the csv matches the common treatment or staggered adoption format
    qui tempname diff_df  
    qui cap frame drop `diff_df'  
    qui frame create `diff_df'
    qui frame change `diff_df'
    qui import delimited "`empty_diff_filepath'", clear stringcols(_all) case(preserve)
    local check_common 1
    foreach header of local expected_common {
        qui capture confirm variable `header'
        if _rc {
            local check_common 0
            break
        }
    }
    local check_staggered 1
    foreach header of local expected_staggered {
        qui capture confirm variable `header'
        if _rc {
            local check_staggered 0
            break
        }
    }
    if (`check_common' == 0 & `check_staggered' == 0) | (`check_common' == 1 & `check_staggered' == 1)  {
        di as error "Error: The loaded CSV does not match the expected staggered adoption or common treatment time formats."
        exit 9
    }
    local found_silo_name = 0 
    qui levelsof silo_name, local(silos) clean
    foreach silo of local silos {
        if "`silo_name'" == "`silo'" {
            local found_silo_name = 1
            continue, break
        }
    }
    if `found_silo_name' == 0 {
        di as error "Error: The silo_name: `silo_name' is not recognized. Must be one of: `silos'."
        exit 5
    }
    qui keep if silo_name == "`silo_name'"
    
    // Check that covariates specified in empty_diff_df exist in the silo data
    local covariates = subinstr(covariates[1], ";", " ", .)
    qui local n_covariates = wordcount("`covariates'")
    local covariates_missing = 0
    local covariates_numeric = 0
    qui frame change default
    if "`covariates'" != "none" {
        forvalues i = 1/`n_covariates' {
            local covariate : word `i' of `covariates'
            qui capture confirm variable `covariate'
            if _rc {
                di as error "`covariate' could not be found in the local silo data."
                local covariates_missing = 1
            }
        }
    }
    if `covariates_missing' == 1 {
         di as error "Consider renaming variables in the local silo to match: `covariates'."
         di as error "Alternatively, set consider_covariates = 0."
         exit 6
    }

    // time_column and outcome_column are implicitly checked for existence in the local silo data
    // Make sure time_column is a string: if its a numeric value there could be severe issues, e.g.
    // if the time_column is years in numeric value that could be either 1991 or, a Stata date object being the 
    // number of days since Jan 1 1960 (11323). Putting time_column into a specific date format removes ambiguity
    // and ensure the date information is processed correctly. Also make sure outcome_column and covariate columns are numeric
    qui cap confirm string variable `time_column'
    if _rc {
        di as error "Error: `time_column' must be a string variable in the given date format (`silo_date_format')."
        exit 7
    }
    qui ds `outcome_column', has(type numeric)
    if "`r(varlist)'" == "" {
        di as error "Error: `outcome_column' must be a numeric variable."
        exit 8
    }
    if "`covariates'" != "none" {
        forvalues i = 1/`n_covariates' {
            local covariate : word `i' of `covariates'
            qui ds `covariate', has(type numeric)
            if "`r(varlist)'" == "" {
                di as error "Error: `covariate' must be a numeric variable."
                local covariates_numeric = 1
            }
        }
    }
    if `covariates_numeric' == 1 {
        exit 9
    }

    // Check for missing values in time_column, outcome_column and covariate columns if applicable
    qui count if missing(`outcome_column')
    if r(N) > 0 {
        di as error "Error: `outcome_column' has `r(N)' missing values!"
        exit 10
    }
    qui count if `time_column' == ""
    if r(N) > 0 {
        di as error "Error: `time_column' has `r(N)' missing values!"
        exit 11
    }
    local covariate_missing_values = 0
    if "`covariates'" != "none" {
        forvalues i = 1/`n_covariates' {
            local covariate : word `i' of `covariates'
            qui count if missing(`covariate')
            if r(N) > 0 {
                di as error "Error: `covariate' has missing values."
                local covariate_missing_values = 1
            }
        }
    }
    if `covariate_missing_values' == 1 {
        di as error "Error: Encountered covariate columns with missing values."
        exit 12
    }

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------- PART TWO: Processing -------------------------------- // 
    // ---------------------------------------------------------------------------------------- //

    if `check_common' == 1 {
        // Compute diff_estimate and diff_var
        qui frame change `diff_df'
        qui levelsof common_treatment_time, local(common_treatment_local) clean
        local cmn_trt_time = word("`common_treatment_local'", 1)
        qui levelsof date_format, local(date_formats) clean
        local diff_df_date_format = word("`date_formats'", 1)
        qui _parse_string_to_date, varname(common_treatment_time) date_format("`diff_df_date_format'") newvar(cmn_trt_date)
        qui summarize cmn_trt_date
        local trt_date = r(min)
        qui frame change default
        tempvar date
        tempvar trt_indicator
        qui _parse_string_to_date, varname(`time_column') date_format("`silo_date_format'") newvar(`date')
        qui gen trt_indicator = (`date' >= `trt_date')
        qui count if trt_indicator == 0
        local count_0 = r(N)
        qui count if trt_indicator == 1
        local count_1 = r(N)
        if `count_0' == 0 | `count_1' == 0 {
            di as error "Error: The local silo must have at least one obs before and after (or at) `cmn_trt_time'."
            exit 13
        }
        qui regress `outcome_column' trt_indicator, robust
        local coef_trt = _b[trt_indicator]
        di as result "Coefficient on trt_indicator: `coef_trt'"

        // Compute diff_estimate_covariates and diff_var_covariates
    }
    else if `check_staggered' == 1 {

    }



    // Convert to Windows-friendly format for display if on Windows
    if "`c(os)'" == "Windows" {
        local fullpath_display_diff = subinstr("`fullpath_diff'", "/", "\", .)
        local fullpath_display_trends = subinstr("`fullpath_trends'", "/", "\", .)
    } 
    else {
        local fullpath_display_diff "`fullpath_diff'"
        local fullpath_display_trends "`fullpath_trends'"
    }
    di as result "filled_diff_df_`silo_name'.csv file saved to: `fullpath_display_diff'"
    di as result "trends_data_`silo_name'.csv file saved to: `fullpath_display_trends'"
    
end

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function