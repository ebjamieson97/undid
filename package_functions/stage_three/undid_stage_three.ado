/*------------------------------------*/
/*undid_stage_three*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-05-04 */
/*------------------------------------*/
cap program drop undid_stage_three
program define undid_stage_three, rclass
    version 16
    syntax, dir_path(string) /// 
            [agg(string) weights(int 1) covariates(int 0) imputation(string) ///
            nperm(int 1001) verbose(int 1)]

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART ONE: Basic Input Checks ------------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    // First, check all the binary inputs:
    // Check weights
    if !inlist(`weights', 0, 1) {
        di as error "Error: weights must be set to 0 (false) or to 1 (true)."
        exit 2
    }
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
    // Check nperm
    if `nperm' < 1 {
        di as error "Error: nperm must be greater than 0"  // Still will need to check compute_nperm_count later on...
        exit 5
    }

    // Check string inputs
    // Check agg
    local agg = lower("`agg'")
    if "`agg'" == "" {
        local agg = "silo"
    }
    if !inlist("`agg'", "silo", "g", "gt", "sgt") {
        di as error "Error: agg must be one of: silo, g, gt, sgt"
        exit 6
    }
    // Check imputation
    local imputation = lower("`imputation'")
    if "`imputation'" != "" {
        if !inlist("`imputation'", "linear_function") {
            di as error "Error: imputation must be blank of one of these options: linear_function"
        }
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
    qui frame change default
    use "`master'", clear

describe
browse

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART THREE: Imputation (if necessary) --------------------- // 
    // ---------------------------------------------------------------------------------------- //

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART FOUR: Compute Results -------------------------------- // 
    // ---------------------------------------------------------------------------------------- //

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART FIVE: Randomization Inference ------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART SIX: Return and Display Results ---------------------- // 
    // ---------------------------------------------------------------------------------------- //

end

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function