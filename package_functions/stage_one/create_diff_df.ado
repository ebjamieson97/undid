/*------------------------------------*/
/*create_diff_df*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-06 */
/*------------------------------------*/
cap program drop create_diff_df
program define create_diff_df
    version 16
    syntax, init_filepath(string) date_format(string) freq(string) ///
            [covariates(string) freq_multiplier(int 1) weights(string) ///
            filename(string) filepath(string)]

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------- PART ONE: Checks ------------------------------------ // 
    // ---------------------------------------------------------------------------------------- // 

    // Define default values
    if missing("`filename'") local filename "empty_diff_df.csv"
    if missing("`weights'") local weights "standard"

    // Remove whitespace from date_format and freq
    local date_format = trim("`date_format'")
    local freq = trim("`freq'")
    
    // If no filepath given, suggest current working directory
    if "`filepath'" == "" {
        local filepath "`c(pwd)'"
        di as error "Error: Please enter a valid filepath to save the CSV such as: `filepath'"
        exit 2
    }

    // Read the init.csv file with all string columns
    qui import delimited "`init_filepath'", clear stringcols(_all)

    // Check for missing values in all columns
    ds
    foreach var in `r(varlist)' {
        cap assert !missing(`var')
        if _rc {
            di as error "Error: Missing values detected in column `var' in the initializing CSV."
            exit 3
        }
    }

    // Make sure freq and treatment_time are lowercase
    qui replace treatment_time = lower(treatment_time)
    qui local freq = lower("`freq'")

    // Trim any whitespace from start_time and end_time
    qui replace start_time = trim(start_time)
    qui replace end_time = trim(end_time)

    // Check that all start_time and end_time values have the same length
    qui gen start_length = strlen(start_time)
    qui gen end_length = strlen(end_time)
    qui sum start_length, meanonly
    cap assert start_length == r(min)
    if _rc {
        di as err "Error: Ensure all start_time values are written in the same date format."
        exit 4
    }
    qui sum end_length, meanonly
    cap assert end_length == r(min)
    if _rc {
        di as err "Error: Ensure all end_time values are written in the same date format."
        exit 5
    }
    cap assert start_length == end_length
    if _rc {
        di as err "Error: Ensure start_time and end_time are written in the same date format."
        exit 6
    }

    // Check that at least one treatment_time is "control" and one is not control
    local found_control = 0
    local found_treated = 0
    qui count if lower(treatment_time) == "control"
    if r(N) > 0 {
        local found_control = 1
    }
    if `found_control' == 0 {
        di as error "Error: At least one treatment_time must be 'control'."
        exit 7
    }
    qui count if lower(treatment_time) != "control"
    if r(N) > 0 {
        local found_treated = 1
    }
    if `found_treated' == 0 {
        di as error "Error: At least one treatment_time must be a non 'control' entry."
        exit 8
    }

    // Check that non control treatment_time entries have the same length as start_length
    qui gen treatment_length = strlen(treatment_time) if lower(treatment_time) != "control"
    qui sum start_length, meanonly
    local ref_length = r(min)
    qui sum treatment_length if !missing(treatment_length), meanonly
    cap assert r(min) == `ref_length' & r(max) == `ref_length'
    if _rc {
        di as error "Error: All non 'control' treatment_time values must written in the same date format as start_time and end_time."
        exit 9
    }

    // Ensure date_format_length == start_length == end_length == treat_length
    local date_format_length = strlen("`date_format'")
    if `date_format_length' != `ref_length' {
        di as error "Error: start_time, end_time and non 'control' treatment_time values must all be written in the date_format specified: `date_format'."
        exit 10
    }
    qui drop start_length
    qui drop end_length
    qui drop treatment_length

    // If covariates are specified, process them
    if "`covariates'" != "" {
        local covariates_trimmed_length = strlen(trim("`covariates'"))
        if `covariates_trimmed_length' == 0 {
            di as error "Error: Covariates cannot be entered as a block of whitespace. To drop covariates entirely, ensure no covariates column is specified in the init.csv."
            exit 14
        }
        local formatted_covariates = subinstr("`covariates'", " ", ";", .)
        cap confirm variable covariates
        if _rc { 
            gen covariates = "`formatted_covariates'"
        }
        else {
            replace covariates = "`formatted_covariates'"
        }
    }

    // Ensure freq_multiplier > 0 
    if `freq_multiplier' < 1 {
        di as error "Error: freq_multiplier must be entered as an integer > 0."
        exit 11
    }

    // ensure date_format and weights are defined in the env
    _undid_env
    local found_date_format = 0
    local found_weights = 0
    foreach format in $UNDID_DATE_FORMATS {
        if "`date_format'" == "`format'" {
            local found_date_format = 1
            continue, break
        }
    }
    if `found_date_format' == 0 {
        di as error "Error: The date_format (`date_format') is not recognized. Must be one of: $UNDID_DATE_FORMATS."
        exit 12
    }
    foreach weight in $UNDID_WEIGHTS {
        if "`weights'" == "`weight'" {
            local found_weights = 1
            continue, break
        }
    }
    if `found_weights' == 0 {
        di as error "Error: The weight (`weights') is not recognized. Must be one of: $UNDID_WEIGHTS."
        exit 13
    }

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------------- PART TWO: Processing -------------------------------- // 
    // ---------------------------------------------------------------------------------------- // 

    // Convert start_time and end_time to dates
    _parse_string_to_date, varname(start_time) date_format("`date_format'") newvar(start_time_2)
    _parse_string_to_date, varname(end_time) date_format("`date_format'") newvar(end_time_2)




end


/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function