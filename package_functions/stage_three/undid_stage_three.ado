/*------------------------------------*/
/*undid_stage_three*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-05-04 */
/*------------------------------------*/
cap program drop undid_stage_three
program define undid_stage_three, rclass
    version 16
    syntax, dir_path(string) /// 
            [agg(string) weights(string) covariates(int 0) use_pre_controls(int 0) ///
            nperm(int 1001) verbose(int 1) seed(int 0)]

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART ONE: Basic Input Checks ------------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    // First, check all the binary inputs:
    // Check covariates
    if !inlist(`covariates', 0, 1) {
        di as error "Error: covariates must be set to 0 (false) or to 1 (true)."
        exit 3
    }
    // Check verbose
    if !inlist(`verbose', 0, 1) {
        di as error "Error: verbose must be set to 0 (false) or to 1 (true)."
        exit 4
    }
    // Check use_pre_controls
    if !inlist(`use_pre_controls', 0, 1) {
        di as error "Error: use_pre_controls must be set to either 0 (false) or 1 (true)."
        exit 8
    }

    // Check other numeric args
    // Check nperm
    if `nperm' < 1 {
        di as error "Error: nperm must be greater than 0"  // Still will need to check compute_nperm_count later on...
        exit 5
    }
    // Process seed
    if "`seed'" != "0" {
        set seed `seed'
    }

    // Check string inputs
    // Check agg
    local agg = lower("`agg'")
    if "`agg'" == "" {
        local agg = "g"
    }
    if !inlist("`agg'", "silo", "g", "gt", "sgt", "none", "time") {
        di as error "Error: agg must be one of: silo, g, gt, sgt, none, time"
        exit 6
    }
    // Check weights
    local weights = lower("`weights'")
    local get_weights = 0
    if "`weights'" == "" {
        local get_weights = 1
    }
    else if !inlist("`weights'", "none", "diff", "att", "both") {
        di as error "Error: weights must be either blank or one of: none, diff, att, both."
    }
    
    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART TWO: Read and Combine Data --------------------------- // 
    // ---------------------------------------------------------------------------------------- // 
    
    // Grab all filled_diff_df file names
    local files : dir "`dir_path'" files "filled_diff_df_*.csv"
    local nfiles : word count `files'
    if `nfiles' == 0 {
        display as error "No filled_diff_df_*.csv files found in `dir_path'"
        exit 7
    }
    di as result `nfiles'

    // Create tempframe to import each csv file and push to a master frame
    tempfile master
    local first = 1
    qui tempname temploadframe
    qui cap frame drop `temploadframe'  
    qui frame create `temploadframe'
    qui frame change `temploadframe'
    foreach f of local files {
        local fn = "`dir_path'/`f'"
        qui import delimited using "`fn'", clear stringcols(_all) case(preserve)

        if `first' {
            qui save "`master'", replace
            local first = 0
        }
        else {
            qui append using "`master'"
            qui save "`master'", replace
        }
    }
    qui use "`master'", clear
    // Grab date format
    local date_format = date_format[1]

    // Check if staggered or common adoption
    local expected_common "silo_name treat common_treatment_time start_time end_time weights diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq n n_t anonymize_size"
    local expected_staggered "silo_name gvar treat diff_times gt RI start_time end_time weights diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq n n_t anonymize_size"
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
        di as error "Error: The loaded CSVs do not match the expected staggered adoption or common treatment time structure."
        exit 9
    }

    // Process columns with potential NA/missing to be missing strings then convert to numeric columns
    foreach var in treat n n_t {
        qui replace `var' = "" if `var' == "NA" | `var' == "missing"
        qui destring `var', replace
    }
    foreach var in diff_estimate diff_estimate_covariates {
        qui replace `var' = "" if `var' == "NA" | `var' == "missing"
        qui destring `var', replace
        qui gen double `var'_tmp = `var'
        qui drop `var'
        qui gen double `var' = `var'_tmp
        qui drop `var'_tmp
        qui format `var' %20.15g 
    }
    if `covariates' == 1 {
        foreach var in diff_estimate_covariates diff_var_covariates {
        qui replace `var' = "" if `var' == "NA" | `var' == "missing"
        qui destring `var', replace
        qui gen double `var'_tmp = `var'
        qui drop `var'
        qui gen double `var' = `var'_tmp
        qui drop `var'_tmp
        qui format `var' %20.15g
        }
    }

    // Set y depending on covariates selection
    if `covariates' == 1 {
        qui gen double y = diff_estimate_covariates
        qui format y %20.15g
        // Check if all values of y are missing
        count if !missing(y)
        if r(N) == 0 {
            di as err "Error: All values of diff_estimate_covariates are missing, try setting covariates(0)."
            exit 10
        }
    }
    else {
        qui gen double y = diff_estimate
        qui format y %20.15g
    }

    // Drop rows where y is missing 
    if `check_staggered' == 1 {
        di as error "Dropping the following silo_name & gt values where y is missing:"
        list silo_name gt if missing(y), noobs sepby(silo_name)
        qui drop if missing(y)
    }
    else if `check_common' == 1 {
        di as error "Dropping the following silo_names for which y is missing:"
        list silo_name if missing(y), noobs sepby(silo_name)
        qui drop if missing(y)
    }

    // If use_pre_controls is toggled on, rearrange the data as necessary
    if `check_staggered' == 1 {
        qui gen t_str = substr(gt, strpos(gt, ";") + 1, .)
        qui _parse_string_to_date, varname(t_str) date_format("`date_format'") newvar(t) 
        qui _parse_string_to_date, varname(gvar) date_format("`date_format'") newvar(gvar_date) 
    }
    if `check_staggered' == 1 & `use_pre_controls' == 1 {
        qui egen double treated_time_silo = min(cond(treat==1, gvar_date, .)), by(silo_name)
        qui replace treat = 0 if treat == -1 & t < treated_time_silo
    }

    // Check that at least one treat and untreated diff exist for each sub-agg ATT computation, drop that sub-agg ATT if not
    // Also do some extra column creating for the dummy indiactors if agg == "time"
    if `check_staggered' == 1 {
        if "`agg'" == "none" {

        }
        else if "`agg'" == "g" {

        }
        else if "`agg'" == "gt" {

        }
        else if "`agg'" == "silo" {

        }
        else if "`agg'" == "sgt" {

        }
        else if "`agg'" == "time" {

        }
    }

    // Force the agg and weights arguments to different strings, depening on how many treated silos there are 
    if `check_common' == 1 {
        qui count if treat == 1
        local treated_count = r(N)
        qui count if treat == 0
        local control_count = r(N)
        if `treated_count' < 1 | `control_count' < 1 {
            di as err "Error: Need at least one treated and one control observation."
            exit 11
        }
        qui levelsof silo_name if treat == 1, local(treated_silos)
        local num_treated_silos : word count `treated_silos'
        if `num_treated_silos' == 1 {
            if inlist("`weights'", "diff", "att", "both") {
                di as error "Warning: only one treated silo detected, setting weights to: diff"
                local weights "diff"
            }
            if inlist("`agg'", "sgt", "silo") {
                di as error "Warning: only one treated silo detected, setting agg to: none"
                local agg "none"
            }
            else if inlist("`agg'", "g", "gt", "time") {
                local agg "none"
            }
        }
        else {
            if inlist("`agg'", "g", "gt", "time") {
                local agg "none"
            }
            else if "`agg'" == "sgt" {
                local agg "silo"
            }
        }
    }

    // Throw error if weights selection depends on n or n_t vals that are NA/missing
    

    qui save "`master'", replace
    qui frame change default
    use "`master'", clear

describe
browse

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART THREE: Compute Results ------------------------------- // 
    // ---------------------------------------------------------------------------------------- //

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART FOUR: Randomization Inference ------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    // Note that if some rows were dropped for staggered adoption this likely skews the interpretation
    // of the randomization inference procedure, especially for agg at the gt or sgt level : if 
    // for example gt of (2000,2000) was dropped for Silo A and there is only one t for that g, 
    // then Silo A can never be assigned as a control (or treat) in subsequent randomizations..
    // ok maybe that doesn't matter actually since its just simply never entered into the computations...

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART FIVE: Return and Display Results --------------------- // 
    // ---------------------------------------------------------------------------------------- //

end

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function