/*------------------------------------*/
/*create_diff_df*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-06 */
/*------------------------------------*/
cap program drop create_diff_df
program define create_diff_df
    version 16
    syntax, init_filepath(string) date_format(string) freq(string) ///
            [covariates(string) freq_multiplier(int -1) weights(string) ///
            filename(string) filepath(string)]

    // Define default values
    if missing("`filename'") local filename "empty_diff_df.csv"
    if missing("`weights'") local weights "standard"
    if `freq_multiplier' == -1 local freq_multiplier 1
    
    // If no filepath given, suggest current working directory
    if "`filepath'" == "" {
        local filepath "`c(pwd)'"
        di as error "Error: Please enter a valid filepath such as: `filepath'"
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
    qui drop start_length
    qui drop end_length
end


/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function