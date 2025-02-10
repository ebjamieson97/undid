/*------------------------------------*/
/*create_init_csv*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-06 */
/*------------------------------------*/
cap program drop create_init_csv
program define create_init_csv
    version 16
    syntax , silo_names(string) start_times(string) end_times(string) ///
             treatment_times(string) [covariates(string)] ///
             [filename(string) filepath(string)]

    // Set default filename if not provided
    if "`filename'" == "" {
        local filename "init.csv"
    }

    // If no filepath given, suggest current working directory
    if "`filepath'" == "" {
        local filepath "`c(pwd)'"
        di as error "Error: Please enter a valid filepath to save the CSV such as: `filepath'"
        exit 2
    }

    // Normalize filepath to always use `/` as the separator
    local filepath_fixed = subinstr("`filepath'", "\", "/", .)
    local fullpath "`filepath_fixed'/`filename'"

    // Split input strings into lists
    local nsilo : list sizeof silo_names
    local nstart : list sizeof start_times
    local nend : list sizeof end_times
    local ntreat : list sizeof treatment_times

    // Ensure required columns have the same length
    if (`nsilo' != `nstart' | `nsilo' != `nend' | `nsilo' != `ntreat') {
        di as error "Error: silo_names, start_times, end_times, and treatment_times must have the same number of elements."
        exit 3
    }

    // Ensure at least two silos
    if (`nsilo' < 2) {
        di as error "Error: UNDID requires at least two silos!"
        exit 4
    }

    // Check that at least one treatment_time is "control" and one is not "control"
    local found_control = 0
    local found_treated = 0
    forval i = 1/`ntreat' {
        local current_value = lower(word("`treatment_times'", `i'))
        if "`current_value'" == "control"  {
            local found_control = 1
            continue, break
        }
    }
    if `found_control' == 0 {
        di as error "Error: At least one treatment_time must be 'control'."
        exit 5
    }
    forval i = 1/`ntreat' {
        local current_value = lower(word("`treatment_times'", `i'))
        if "`current_value'" != "control" {
            local found_treated = 1
            continue, break
        }
    }
    if `found_treated' == 0 {
        di as error "Error: At least one treatment_time must be a non 'control' entry."
        exit 6
    }


    // Open a new frame for storing data
    tempname init_data
    cap frame drop `init_data'
    frame create `init_data'
    frame change `init_data'

    // Set the number of observations
    set obs `nsilo'
    
    // Create variables
    gen silo_name = ""
    gen start_time = ""
    gen end_time = ""
    gen treatment_time = ""

    // Populate the data row by row
    forval i = 1/`nsilo' {
        replace silo_name = word("`silo_names'", `i') in `i'
        replace start_time = word("`start_times'", `i') in `i'
        replace end_time = word("`end_times'", `i') in `i'
        replace treatment_time = lower(word("`treatment_times'", `i')) in `i'
    }

    // Handle optional covariates
    if "`covariates'" != "" {
        gen covariates = ""

        // Convert covariates into a single semicolon-separated string
        local covariates_combined = subinstr("`covariates'", " ", ";", .)

        // Copy and paste to all rows
        replace covariates = "`covariates_combined'"
    }
    
    // Export as CSV
    export delimited using "`fullpath'", replace

    // Return to default frame
    frame change default

    di as result "CSV file saved at: `fullpath'"
    
end

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function