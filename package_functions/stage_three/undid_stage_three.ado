/*------------------------------------*/
/*undid_stage_three*/
/*written by Eric Jamieson */
/*version 0.0.1 2025-08-07 */
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
        exit 15
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
    if `get_weights' == 1 {
        local weights = weights[1]
    }

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
    foreach var in diff_estimate diff_var {
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
        qui gen double yvar =  diff_var_covariates
        qui format yvar %20.15g
    }
    else {
        qui gen double y = diff_estimate
        qui format y %20.15g
        qui gen double yvar = diff_var
        qui format yvar %20.15g
    }

    // Drop rows where y is missing 
    if `check_staggered' == 1 {
        qui count if missing(y)
        local nmiss = r(N)
        if `nmiss' > 0 {
            di as error "Dropping the following rows where y is missing:"
            list silo_name gt treat if missing(y), noobs sepby(silo_name)
            qui drop if missing(y)
        }
    }
    else if `check_common' == 1 {
        qui count if missing(y)
        local nmiss = r(N)
        if `nmiss' > 0 {
            di as error "Dropping the following silo_names for which y is missing:"
            list silo_name if missing(y), noobs sepby(silo_name)
            qui drop if missing(y)
        }
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
        qui drop treated_time_silo
    }

    // Check that at least one treat and untreated diff exist for each sub-agg ATT computation, drop that sub-agg ATT if not
    // Also do some extra processing if agg == "time" then create the time column which indicates periods since treatment
    if `check_staggered' == 1 {
        if "`agg'" == "none" {
            if inlist("`weights'", "att", "both") {
                di as err "Warning: weighting methods 'att' and 'both' are not applicable to aggregation method of 'none' as they apply weights to sub-aggregate ATTs which are not caluclated with 'agg = none'. Overwriting weights to 'diff'."
                local weights "diff"
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
        }
        if inlist("`agg'", "g", "silo") {
            qui levelsof gvar, local(gvars)
            foreach g of local gvars {
                qui count if treat == 1 & gvar == "`g'"
                local treated_count = r(N)
                qui count if treat == 0 & gvar == "`g'"
                local control_count = r(N)
                if `treated_count' < 1 | `control_count' < 1 {
                    di as err "Warning: Could not find at least one treated and one control observation for gvar = `g'."
                    di as err "Warning: Dropping rows where gvar = `g'."
                    qui drop if gvar == "`g'"
                }
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
        }
        if inlist("`agg'", "gt", "sgt") {
            qui levelsof gt, local(gts)
            foreach gt of local gts {
                qui count if treat == 1 & gt == "`gt'"
                local treated_count = r(N)
                qui count if treat == 0 & gt == "`gt'"
                local control_count = r(N)
                if `treated_count' < 1 | `control_count' < 1 {
                    di as err "Warning: Could not find at least one treated and one control observation for gt = `gt'."
                    di as err "Warning: Dropping rows where gt = `gt'."
                    qui drop if gt == "`gt'"
                }
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
        }
        if "`agg'" == "silo" {
            qui levelsof silo_name if treat == 1, local(treated_silos)
            local num_treated_silos : word count `treated_silos'
            if `num_treated_silos' < 1 {
                di as error "Error: Could not find any treated silos!"
                exit 12
            }
            foreach s of local treated_silos {
                qui levelsof gvar if silo_name == "`s'" & treat == 1, local(silo_gvar)
                foreach g of local silo_gvar {
                    // Implictly already determined that there will be at least one treated obs so can just count control obs
                    qui count if treat == 0 & gvar == "`g'"
                    local control_count = r(N)
                    if `control_count' < 1 {
                        di as err "Warning: Could not find at least one control obs where gvar = `g' to match to treat = 1 & silo_name = `s' & gvar = `g'."
                        di as err "Warning: Dropping rows where treat = 1 & gvar == `g' & silo_name == `s'"
                        qui drop if treat == 1 & gvar == "`g'" & silo_name == "`s'"
                    }
                }
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
        }
        if "`agg'" == "sgt" {
            qui levelsof silo_name if treat == 1, local(treated_silos)
            local num_treated_silos : word count `treated_silos'
            if `num_treated_silos' < 1 {
                di as error "Error: Could not find any treated silos!"
                exit 12
            }
            foreach s of local treated_silos {
                qui levelsof gt if silo_name == "`s'" & treat == 1, local(silo_gts)
                foreach gt of local silo_gts {
                    // Implictly already determined that there will be at least one treated obs so can just count control obs
                    qui count if treat == 0 & gt == "`gt'"
                    local control_count = r(N)
                    if `control_count' < 1 {
                        di as err "Warning: Could not find at least one control obs where gt = `gt' to match to treat = 1 & silo_name = `s' & gt = `gt'."
                        di as err "Warning: Dropping rows where treat = 1 & gt == `gt' & silo_name == `s'"
                        qui drop if treat == 1 & gt == "`gt'" & silo_name == "`s'"
                    }
                }
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
        }
        if "`agg'" == "time" {
            qui gen double time = .
            qui gen freq_n = real(word(freq, 1))
            qui gen freq_unit = lower(word(freq, 2))
            if substr(freq_unit, 1, 3) == "yea" {
                qui replace time = floor((year(t) - year(gvar_date)) / freq_n)
            }
            else if substr(freq_unit, 1, 3) == "mon" {
                qui replace time = floor((ym(year(t),  month(t)) - ym(year(gvar_date), month(gvar_date))) / freq_n)
            }
            else if substr(freq_unit, 1, 3) == "wee" {
                qui replace time = floor((t - gvar_date) / (7 * freq_n))
            }
            else if substr(freq_unit, 1, 3) == "day" { 
                qui replace time = floor((t - gvar_date) / freq_n)
            }
            qui drop freq_n
            qui drop freq_unit
            qui levelsof time, local(time_groups)
            foreach time_g of local time_groups {
                qui count if treat == 1 & time == `time_g'
                local treated_count = r(N)
                qui count if treat == 0 & time == `time_g'
                local control_count = r(N)
                if `treated_count' < 1 | `control_count' < 1 {
                    di as err "Warning: Could not find at least one treated and one control obs for periods since treatment: `time_g'."
                    di as err "Dropping all rows where periods since treatment = `time_g'."
                    qui drop if time == `time_g'
                }
            }
            qui count if treat == 1
            local treated_count = r(N)
            qui count if treat == 0
            local control_count = r(N)
            if `treated_count' < 1 | `control_count' < 1 {
                di as err "Error: Need at least one treated and one control observation."
                exit 11
            }
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
        if (!inlist("`agg'", "silo", "sgt")) & inlist("`weights'", "att", "both") {
            di as error "Warning: weighting methods 'att' and 'both' are only applicable to aggregation method of 'silo' or 'sgt' for common adoption scenarios as they apply weights to sub-aggregate ATTs which are not caluclated in a common adoption scenario when agg is any of 'g', 'gt', 'time', or 'none'. Overwriting weights to 'diff'."
            local weights "diff"
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
            else if inlist("`agg'", "sgt", "silo") {
                local agg "silo"
                qui rename common_treatment_time gvar
                qui _parse_string_to_date, varname(gvar) date_format("`date_format'") newvar(gvar_date)
                // This is the same check used in the staggered checks block preceding this section: 
                qui levelsof silo_name if treat == 1, local(treated_silos)
                local num_treated_silos : word count `treated_silos'
                if `num_treated_silos' < 1 {
                    di as error "Error: Could not find any treated silos!"
                    exit 12
                }
                foreach s of local treated_silos {
                    qui levelsof gvar if silo_name == "`s'" & treat == 1, local(silo_gvar)
                    foreach g of local silo_gvar {
                        // Implictly already determined that there will be at least one treated obs so can just count control obs
                        qui count if treat == 0 & gvar == "`g'"
                        local control_count = r(N)
                        if `control_count' < 1 {
                            di as err "Warning: Could not find at least one control obs where gvar = `g' to match to treat = 1 & silo_name = `s' & gvar = `g'."
                            di as err "Warning: Dropping rows where treat = 1 & gvar == `g' & silo_name == `s'"
                            qui drop if treat == 1 & gvar == "`g'" & silo_name == "`s'"
                        }
                    }
                }
                qui count if treat == 1
                local treated_count = r(N)
                qui count if treat == 0
                local control_count = r(N)
                if `treated_count' < 1 | `control_count' < 1 {
                    di as err "Error: Need at least one treated and one control observation."
                    exit 11
                }
            }
        }
    }

    // Throw error if weights selection depends on n or n_t vals that are NA/missing
    if inlist("`weights'", "diff", "both") {
        qui count if missing(n)
        local n_missing = r(N)
        if `n_missing' > 0 {
            di as error "Error: missing counts of n which are required with weighting options: diff and both"
            exit 13
        }
    }
    if inlist("`weights'", "att", "both") {
        qui count if missing(n_t)
        local n_t_missing = r(N)
        if `n_t_missing' > 0 {
            di as error "Error: missing counts of n_t which are required with weighting options: att and both"
            exit 14
        }
    }

    // After all the pre-processing checks are done, can finally move on to regressions


    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART THREE: Compute Results ------------------------------- // 
    // ---------------------------------------------------------------------------------------- //

    // Create a column of ones for the regressions
    qui gen byte const = 1

    // Define some tempnames for scalars for the aggregate levels results 
    qui tempname agg_att 
    qui tempname agg_att_se 
    qui tempname agg_att_jknife_se 
    qui tempname agg_att_pval 
    qui tempname agg_att_jknife_pval
    qui tempname agg_att_tstat
    qui tempname agg_att_tstat_jknife
    qui tempname agg_att_dof
    
    // For storing counts and other scalars
    qui tempname total_n
    qui tempname total_n_t
    qui tempname sub_agg_dof
    qui tempname sub_agg_tstat

    // For edge cases
    qui tempname trt0_var
    qui tempname trt0_weight
    qui tempname trt1_var
    qui tempname trt1_weight

    // Define some locals to store the sub-aggregate level results
    local sub_agg_label ""
    local sub_agg_atts ""
    local sub_agg_atts_se ""
    local sub_agg_atts_pval ""
    local sub_agg_atts_jknife ""
    local sub_agg_atts_jknife_pval ""
    local sub_agg_atts_ri_pval ""
    local sub_agg_weights ""

    if "`agg'" == "none" {
        // Still need to add functionality with common adoption (and its edge case)
        // Basically, should manually calculate the edge case for common adoption
        preserve
        qui keep if treat >= 0
        if "`weights'" == "diff" {
            qui sum n 
            qui scalar `total_n' = r(sum)
            qui gen w = n / `total_n'
            qui gen double sw = sqrt(w)
            qui replace y = y * sw
            qui replace treat = treat * sw
            qui replace const = const * sw
        }
        qui reg y const treat if treat >= 0, noconstant vce(robust)
        qui scalar `agg_att' = _b[treat]
        qui scalar `agg_att_se' = _se[treat]
        qui scalar `agg_att_dof' = e(df_r)
        qui count if treat > 0
        local treated_obs = r(N)
        qui count if treat == 0 
        local control_obs = r(N)
        if `treated_obs' + `control_obs' == 2 { //Only two obs - can't compute standard errors for staggered
            if `check_staggered' == 1 {
                qui scalar `agg_att_se' = .
                qui scalar `agg_att_pval' = .
                qui scalar `agg_att_jknife_se' = .
                qui scalar `agg_att_jknife_pval' = .
            }
            else if `check_common' == 1 {
                // Can manually compute standard error here, but not pval
                qui count if missing(yvar)
                local nmiss = r(N)
                if `nmiss' > 0 {
                    di as error "Warning: Missing values of variance estimate, could not compute the standard error!"
                    local sub_agg_att_se "."
                }
                else {
                    qui summ yvar if treat == 0, meanonly
                    qui scalar `trt0_var' = r(min)
                    qui summ yvar if treat > 0, meanonly
                    qui scalar `trt1_var' = r(min)
                    if "`weights'" == "diff" {
                        qui sum n if treat >= 0 
                        qui scalar `total_n' = r(sum)
                        qui sum n if treat == 0 
                        qui scalar `trt0_weight' = (r(min) / `total_n')^2
                        qui sum n if treat > 0 
                        qui scalar `trt1_weight' = (r(min) / `total_n')^2
                        qui scalar `agg_att_se' = sqrt((`trt1_var' * `trt1_weight' + `trt0_var' * `trt0_weight')/(`trt0_weight' + `trt1_weight'))
                    } 
                    else {
                        qui scalar `agg_att_se' = sqrt(`trt1_var' + `trt0_var')
                    }
                }
                qui scalar `agg_att_pval' = .
                qui scalar `agg_att_jknife_se' = .
                qui scalar `agg_att_jknife_pval' = .
            }
        }
        else if `treated_obs' == 1 | `control_obs' == 1 { // If only one of treated_obs or control_obs, can't compute jackknife
                qui scalar `agg_att_tstat' = `agg_att' / `agg_att_se'
                qui scalar `agg_att_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat'))
                qui scalar `agg_att_jknife_se' = .
                qui scalar `agg_att_jknife_pval' = .
        }
        else {
            qui scalar `agg_att_tstat' = `agg_att' / `agg_att_se'
            qui scalar `agg_att_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat'))
            qui reg y const treat if treat >= 0, noconstant vce(jackknife)
            qui scalar `agg_att_dof' = e(N) - 1
            qui scalar `agg_att_jknife_se' = _se[treat]
            qui scalar `agg_att_tstat_jknife' = `agg_att' / `agg_att_jknife_se'
            qui scalar `agg_att_jknife_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat_jknife'))
        }
        restore
    } 
    else if "`agg'" == "g" {
        qui levelsof gvar, local(gvars)
        foreach g of local gvars {
            preserve 
            qui keep if gvar == "`g'" & treat >= 0
            if inlist("`weights'", "diff", "both") {
                qui sum n
                qui scalar `total_n' = r(sum)
                qui gen w = n / `total_n'
                qui gen double sw = sqrt(w)
                qui replace y = y * sw
                qui replace treat = treat * sw
                qui replace const = const * sw
            }

            if inlist("`weights'", "att", "both") {
                qui sum n_t if treat > 0 
                qui scalar `total_n_t' = r(sum)
                local sub_agg_weights "`sub_agg_weights' `=scalar(`total_n_t')'"
            }
            else {
                local sub_agg_weights "`sub_agg_weights' ."
            }
            
            qui reg y const treat if treat >= 0, noconstant vce(robust)
            local sub_agg_att = _b[treat]
            qui scalar `sub_agg_dof' = e(df_r)
            if `sub_agg_dof' > 0 {
                local sub_agg_att_se = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                local sub_agg_att_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }
            else {
                local sub_agg_att_se "."
                local sub_agg_att_pval "."
            }
            
            qui count if treat > 0
            local treated_obs = r(N)
            qui count if treat == 0
            local control_obs = r(N)
            if `treated_obs' == 1 | `control_obs' == 1 {
                local sub_agg_att_jknife "."
                local sub_agg_att_jknife_pval "."
            }
            else {
                qui reg y const treat if treat >= 0, noconstant vce(jackknife)
                local sub_agg_att_jknife = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                qui scalar `sub_agg_dof' = e(N) - 1
                local sub_agg_att_jknife_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }      

            local sub_agg_label "`sub_agg_label' `g'"
            local sub_agg_atts "`sub_agg_atts' `sub_agg_att'"
            local sub_agg_atts_se "`sub_agg_atts_se' `sub_agg_att_se'"
            local sub_agg_atts_pval "`sub_agg_atts_pval' `sub_agg_att_pval'"
            local sub_agg_atts_jknife "`sub_agg_atts_jknife' `sub_agg_att_jknife'"
            local sub_agg_atts_jknife_pval "`sub_agg_atts_jknife_pval' `sub_agg_att_jknife_pval'"
            restore
        }
    }
    else if "`agg'" == "gt" {
        qui levelsof gt, local(gts)
        foreach gt of local gts {
            preserve
            qui keep if gt == "`gt'" & treat >= 0
            if inlist("`weights'", "diff", "both") {
                qui sum n
                qui scalar `total_n' = r(sum)
                qui gen w = n / `total_n'
                qui gen double sw = sqrt(w)
                qui replace y = y * sw
                qui replace treat = treat * sw
                qui replace const = const * sw
            }

            if inlist("`weights'", "att", "both") {
                qui sum n_t if treat > 0
                qui scalar `total_n_t' = r(sum)
                local sub_agg_weights "`sub_agg_weights' `=scalar(`total_n_t')'"
            }
            else {
                local sub_agg_weights "`sub_agg_weights' ."
            }
            
            qui reg y const treat if treat >= 0, noconstant vce(robust)
            local sub_agg_att = _b[treat]
            qui scalar `sub_agg_dof' = e(df_r)
            if `sub_agg_dof' > 0 {
                local sub_agg_att_se = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                local sub_agg_att_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }
            else {
                qui count if missing(yvar)
                local nmiss = r(N)
                if `nmiss' > 0 {
                    di as error "Warning: Missing values of variance estimate, could not compute the standard error for gt: `gt'"
                    local sub_agg_att_se "."
                }
                else {
                    qui summ yvar if treat == 0, meanonly
                    qui scalar `trt0_var' = r(min)
                    qui summ yvar if treat > 0, meanonly
                    qui scalar `trt1_var' = r(min)
                    if inlist("`weights'", "diff", "both") {
                        qui sum n if treat >= 0 
                        qui scalar `total_n' = r(sum)
                        qui sum n if treat == 0 
                        qui scalar `trt0_weight' = (r(min) / `total_n')^2
                        qui sum n if treat > 0 
                        qui scalar `trt1_weight' = (r(min) / `total_n')^2
                        local sub_agg_att_se = sqrt((`trt1_var' * `trt1_weight' + `trt0_var' * `trt0_weight')/(`trt0_weight' + `trt1_weight'))
                    } 
                    else {
                        local sub_agg_att_se = sqrt(`trt1_var' + `trt0_var')
                    }
                }
                local sub_agg_att_pval "."
            }
            
            qui count if treat > 0
            local treated_obs = r(N)
            qui count if treat == 0
            local control_obs = r(N)
            if `treated_obs' == 1 | `control_obs' == 1 {
                    local sub_agg_att_jknife "."
                    local sub_agg_att_jknife_pval "."
            }
            else {
                qui reg y const treat if treat >= 0, noconstant vce(jackknife)
                local sub_agg_att_jknife = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                qui scalar `sub_agg_dof' = e(N) - 1
                local sub_agg_att_jknife_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }            

            local sub_agg_label "`sub_agg_label' `gt'"
            local sub_agg_atts "`sub_agg_atts' `sub_agg_att'"
            local sub_agg_atts_se "`sub_agg_atts_se' `sub_agg_att_se'"
            local sub_agg_atts_pval "`sub_agg_atts_pval' `sub_agg_att_pval'"
            local sub_agg_atts_jknife "`sub_agg_atts_jknife' `sub_agg_att_jknife'"
            local sub_agg_atts_jknife_pval "`sub_agg_atts_jknife_pval' `sub_agg_att_jknife_pval'"
            restore
        }
    }
    else if "`agg'" == "silo" {
        qui levelsof silo_name if treat == 1, local(silos)
        foreach s of local silos {
            preserve
            qui levelsof gvar if silo_name == "`s'" & treat == 1, local(g)
            qui keep if ((silo_name == "`s'" & treat == 1) | (treat == 0 & gvar == `g' & silo_name != "`s'"))
            if inlist("`weights'", "diff", "both") {
                qui sum n
                qui scalar `total_n' = r(sum)
                qui gen w = n / `total_n'
                qui gen double sw = sqrt(w)
                qui replace y = y * sw
                qui replace treat = treat * sw
                qui replace const = const * sw
            }

            if inlist("`weights'", "att", "both") {
                qui sum n_t if treat > 0
                qui scalar `total_n_t' = r(sum)
                local sub_agg_weights "`sub_agg_weights' `=scalar(`total_n_t')'"
            }
            else {
                local sub_agg_weights "`sub_agg_weights' ."
            }
            
            qui reg y const treat if treat >= 0, noconstant vce(robust)
            local sub_agg_att = _b[treat]
            qui scalar `sub_agg_dof' = e(df_r)
            if `sub_agg_dof' > 0 {
                local sub_agg_att_se = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                local sub_agg_att_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }
            else {
                local sub_agg_att_se "."
                local sub_agg_att_pval "."
            }
            
            qui count if treat > 0
            local treated_obs = r(N)
            qui count if treat == 0
            local control_obs = r(N)
            if `treated_obs' == 1 | `control_obs' == 1 {
                    local sub_agg_att_jknife "."
                    local sub_agg_att_jknife_pval "."
            }
            else {
                qui reg y const treat if treat >= 0, noconstant vce(jackknife)
                local sub_agg_att_jknife = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                qui scalar `sub_agg_dof' = e(N) - 1
                local sub_agg_att_jknife_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }          

            local sub_agg_label "`sub_agg_label' `s'"
            local sub_agg_atts "`sub_agg_atts' `sub_agg_att'"
            local sub_agg_atts_se "`sub_agg_atts_se' `sub_agg_att_se'"
            local sub_agg_atts_pval "`sub_agg_atts_pval' `sub_agg_att_pval'"
            local sub_agg_atts_jknife "`sub_agg_atts_jknife' `sub_agg_att_jknife'"
            local sub_agg_atts_jknife_pval "`sub_agg_atts_jknife_pval' `sub_agg_att_jknife_pval'"
            restore
        }        
    }
    else if "`agg'" == "sgt" {
        qui levelsof silo_name if treat == 1, local(silos)
        foreach s of local silos {
            qui levelsof gt if silo_name == "`s'" & treat == 1, local(gts)
            foreach gt of local gts {
                preserve
                qui keep if ((silo_name == "`s'" & treat == 1 & gt == "`gt'") | (treat == 0 & gt == "`gt'" & silo_name != "`s'"))
                if inlist("`weights'", "diff", "both") {
                    qui sum n
                    qui scalar `total_n' = r(sum)
                    qui gen w = n / `total_n'
                    qui gen double sw = sqrt(w)
                    qui replace y = y * sw
                    qui replace treat = treat * sw
                    qui replace const = const * sw
                }

                if inlist("`weights'", "att", "both") {
                    qui sum n_t if treat > 0 
                    qui scalar `total_n_t' = r(sum)
                    local sub_agg_weights "`sub_agg_weights' `=scalar(`total_n_t')'"
                }
                else {
                    local sub_agg_weights "`sub_agg_weights' ."
                }

                qui reg y const treat if treat >= 0, noconstant vce(robust)
                local sub_agg_att = _b[treat]
                qui scalar `sub_agg_dof' = e(df_r)
                if `sub_agg_dof' > 0 {
                    local sub_agg_att_se = _se[treat]
                    qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                    local sub_agg_att_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
                }
                else {
                    qui count if missing(yvar)
                    local nmiss = r(N)
                    if `nmiss' > 0 {
                        di as error "Warning: Missing values of variance estimate, could not compute the standard error for gt: `gt'"
                        local sub_agg_att_se "."
                    }
                    else {
                        qui summ yvar if treat == 0, meanonly
                        qui scalar `trt0_var' = r(min)
                        qui summ yvar if treat > 0, meanonly
                        qui scalar `trt1_var' = r(min)
                        if inlist("`weights'", "diff", "both") {
                            qui sum n if treat >= 0 
                            qui scalar `total_n' = r(sum)
                            qui sum n if treat == 0 
                            qui scalar `trt0_weight' = (r(min) / `total_n')^2
                            qui sum n if treat > 0 
                            qui scalar `trt1_weight' = (r(min) / `total_n')^2
                            local sub_agg_att_se = sqrt((`trt1_var' * `trt1_weight' + `trt0_var' * `trt0_weight')/(`trt0_weight' + `trt1_weight'))
                        } 
                        else {
                            local sub_agg_att_se = sqrt(`trt1_var' + `trt0_var')
                        }
                    }
                    local sub_agg_att_pval "."
                }

                qui count if treat > 0
                local treated_obs = r(N)
                qui count if treat == 0
                local control_obs = r(N)
                if `treated_obs' == 1 | `control_obs' == 1 {
                    local sub_agg_att_jknife "."
                    local sub_agg_att_jknife_pval "."
                }
                else {
                    qui reg y const treat if treat >= 0, noconstant vce(jackknife)
                    local sub_agg_att_jknife = _se[treat]
                    qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                    qui scalar `sub_agg_dof' = e(N) - 1
                    local sub_agg_att_jknife_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
                }            

                local sub_agg_label "`sub_agg_label' "`s'_`gt'""
                local sub_agg_atts "`sub_agg_atts' `sub_agg_att'"
                local sub_agg_atts_se "`sub_agg_atts_se' `sub_agg_att_se'"
                local sub_agg_atts_pval "`sub_agg_atts_pval' `sub_agg_att_pval'"
                local sub_agg_atts_jknife "`sub_agg_atts_jknife' `sub_agg_att_jknife'"
                local sub_agg_atts_jknife_pval "`sub_agg_atts_jknife_pval' `sub_agg_att_jknife_pval'"
                restore
            }  
        }        
    }
    else if "`agg'" == "time" {
        qui levelsof time, local(times)
        foreach t of local times {
            preserve
            qui keep if time == `t' & treat >= 0
            if inlist("`weights'", "diff", "both") {
                qui sum n
                qui scalar `total_n' = r(sum)
                qui gen w = n / `total_n'
                qui gen double sw = sqrt(w)
                qui replace y = y * sw
                qui replace treat = treat * sw
                qui replace const = const * sw
            }

            if inlist("`weights'", "att", "both") {
                qui sum n_t if treat > 0
                qui scalar `total_n_t' = r(sum)
                local sub_agg_weights "`sub_agg_weights' `=scalar(`total_n_t')'"
            }
            else {
                local sub_agg_weights "`sub_agg_weights' ."
            }

            qui count if treat > 0
            local treated_obs = r(N)
            qui count if treat == 0
            local control_obs = r(N)

            qui sum gvar_date, meanonly
            local min_gvar = r(min)
            
            qui reg y const treat c.sw#ib`min_gvar'.(gvar_date) if treat >= 0, noconstant vce(robust)
            local sub_agg_att = _b[treat]
            qui scalar `sub_agg_dof' = e(df_r)
            if `sub_agg_dof' > 0 {
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                local sub_agg_att_se = _se[treat]
                local sub_agg_att_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }
            else {
                local sub_agg_att_se "."
                local sub_agg_att_pval "."
            }

            if `treated_obs' == 1 | `control_obs' == 1 {
                local sub_agg_att_jknife "."
                local sub_agg_att_jknife_pval "."
            }
            else {
                qui reg y const treat c.sw#ib`min_gvar'.(gvar_date) if treat >= 0, noconstant vce(jackknife)
                local sub_agg_att_jknife = _se[treat]
                qui scalar `sub_agg_tstat' = _b[treat] / _se[treat]
                qui scalar `sub_agg_dof' = e(N) - 1
                    local sub_agg_att_jknife_pval = 2 * ttail(`sub_agg_dof', abs(`sub_agg_tstat'))
            }            

            local sub_agg_label "`sub_agg_label' `t'"
            local sub_agg_atts "`sub_agg_atts' `sub_agg_att'"
            local sub_agg_atts_se "`sub_agg_atts_se' `sub_agg_att_se'"
            local sub_agg_atts_pval "`sub_agg_atts_pval' `sub_agg_att_pval'"
            local sub_agg_atts_jknife "`sub_agg_atts_jknife' `sub_agg_att_jknife'"
            local sub_agg_atts_jknife_pval "`sub_agg_atts_jknife_pval' `sub_agg_att_jknife_pval'"
            restore
        }
    }

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART FOUR: Randomization Inference ------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    // Part 4a : Compute n_unique_assignments

    // If common treatment scenario and gvar doesnt exist, create it 
    if `check_common' == 1 & "`agg'" != "silo" {
        qui rename common_treatment_time gvar
        qui _parse_string_to_date, varname(gvar) date_format("`date_format'") newvar(gvar_date)
    }

    // Compute numerator
    qui levelsof silo_name, local(unique_silos)
    local n_silos: word count `unique_silos'
    local ln_num = lnfactorial(`n_silos')

    // Grab all of the gvar assignments and treated silos and compute denominator
    preserve 
        qui keep if treat == 1
        qui bysort silo_name: egen min_gvar= min(gvar_date)
        qui keep if gvar_date == min_gvar
        qui drop min_gvar
        qui contract gvar silo_name

        local gvar_assignments ""
        qui count
         forvalues i = 1/`r(N)' {
            local current_gvar = gvar[`i']
            local gvar_assignments "`gvar_assignments' `current_gvar'"
        }
    
        // Compute first part of the denominator
        local n_gvar_assignments: word count `gvar_assignments'
        local ln_den = lnfactorial(`n_silos' - `n_gvar_assignments')
    
        // Compute frequencies of unique gvar values and their factorial contributions
        qui levelsof gvar, local(unique_gvars)
        foreach m in `unique_gvars' {
            qui count if gvar == "`m'"
            local n_m = r(N)
            local ln_den = `ln_den' + lnfactorial(`n_m')
        }
        restore
    
    // Compute the final result and return scalar
    // Note that this calculation may end up being different from Julia's due to floating point precision... 
    // e.g. for 51 states (10 treated), Julia gives 5795970104231798 while Stata gives 5795970104232000 (difference of less than 0.000000001%)
    qui tempname n_unique_assignments_scalar
    local n_unique_assignments_local = exp(`ln_num' - `ln_den')
    qui scalar `n_unique_assignments_scalar' = floor(`n_unique_assignments_local')

    // Part 4b : Randomize treatment assignments

    // Should probably do in a while loop with some counter for trying to find random assignments (try 1000 times until breaking?) 


    // ---------------------------------------------------------------------------------------- //
    // -------- PART FIVE: Return and Display Results, and Compute Aggregate Values ----------- // 
    // ---------------------------------------------------------------------------------------- //

    if "`agg'" != "none" {
        di as text "-----------------------------------------------------------------------------------------------------"
		di as text "                                     undid: Sub-Aggregate Results                    "
		di as text "-----------------------------------------------------------------------------------------------------"
		di as text "Sub-Aggregate Group       | " as text "ATT             | SE     | p-val  | JKNIFE SE  | JKNIFE p-val | RI p-val"
		di as text "--------------------------|-----------------|--------|--------|------------|--------------|---------|"  
		
		// Initialize a temporary matrix to store the numeric results
        tempname weight_total
        qui scalar `weight_total' = 0
        tempname table_matrix
        local nrows : word count `sub_agg_label'  
        local num_cols = 7
        qui matrix `table_matrix' = J(`nrows', `num_cols', .)
		
		forvalues i = 1/`nrows' {
            local lbl     : word `i' of `sub_agg_label'
            local att     : word `i' of `sub_agg_atts'
            local se      : word `i' of `sub_agg_atts_se'
            local pval    : word `i' of `sub_agg_atts_pval'
            local jse     : word `i' of `sub_agg_atts_jknife'
            local jpval   : word `i' of `sub_agg_atts_jknife_pval'
            local sub_agg_weight : word `i' of `sub_agg_weights'
			di as text %-25s "`lbl'" as text " |" as result %-16.7f real("`att'") as text " | " as result  %-7.3f real("`se'") as text "| " as result %-7.3f real("`pval'") as text "| " as result  %-11.3f real("`jse'") as text "| " as result %-13.3f real("`jpval'") as text "|" as result %-9.3f "." as text "|"
    
			di as text "--------------------------|-----------------|--------|--------|------------|--------------|---------|"
            
            // Fill the matrix with numeric values
            matrix `table_matrix'[`i', 1] = real("`att'")
            matrix `table_matrix'[`i', 2] = real("`se'")
            matrix `table_matrix'[`i', 3] = real("`pval'")
            matrix `table_matrix'[`i', 4] = real("`jse'")
            matrix `table_matrix'[`i', 5] = real("`jpval'")
            // matrix `table_matrix'[`i', 6] = `tmp_ri_pval_att_t'[`i']
            matrix `table_matrix'[`i', 7]  = .
            
            qui scalar `weight_total' = `weight_total' + `sub_agg_weight'
		}

        if inlist("`weights'", "att", "both") {
            forvalues i = 1/`nrows' {
                local sub_agg_weight : word `i' of `sub_agg_weights'
                matrix `table_matrix'[`i', 7] = `sub_agg_weight' / `weight_total'
            } 
        }

		// Set column names for the matrix
        matrix colnames `table_matrix' = ATT SE pval JKNIFE_SE JKNIFE_pval RI_pval W
        
        // Set row names for the matrix using the labels
        matrix rownames `table_matrix' = `sub_agg_label'
        
        // Compute aggregate results
        clear
        qui svmat double `table_matrix', names(col)
        qui gen byte const = 1
        if inlist("`weights'", "att", "both") {
            qui gen double sw = sqrt(W)
            qui replace ATT = ATT * sw
            qui replace const = const * sw
        }

        // Compute aggregate ATT and robust SE
        if `nrows'  > 1 {
            qui reg ATT const, noconstant vce(robust)
            qui scalar `agg_att' = _b[const]
            qui scalar `agg_att_se' = _se[const]
            qui scalar `agg_att_dof' = e(df_r)
            qui scalar `agg_att_tstat' = `agg_att' / `agg_att_se'
            qui scalar `agg_att_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat'))
        }
        else {
            qui scalar `agg_att' = ATT
            qui scalar `agg_att_se' = .
            qui scalar `agg_att_pval' = .
        }

        // Compute jackknife SE
        if `nrows' > 2 {
            qui reg ATT const, noconstant vce(jackknife)
            qui scalar `agg_att_jknife_se' = _se[const]
            qui scalar `agg_att_tstat_jknife' = `agg_att' / `agg_att_jknife_se'
            qui scalar `agg_att_jknife_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat_jknife'))
        }
        else if `nrows' == 2 { // Manually compute since vce(jackknife) fails for n = 2
            qui scalar `agg_att_jknife_se' = sqrt( ((2-1)/2) * ((ATT[1] - `agg_att')^2 + (ATT[2] - `agg_att')^2))
            qui scalar `agg_att_tstat_jknife' = `agg_att' / `agg_att_jknife_se'
            qui scalar `agg_att_jknife_pval' = 2 * ttail(`agg_att_dof', abs(`agg_att_tstat_jknife'))
        }
        else {
            qui scalar `agg_att_jknife_se' = .
            qui scalar `agg_att_jknife_pval' = .
        }
        
        

        // Store the matrix in r()
        return matrix undid = `table_matrix'

		local linesize = c(linesize)
		if `linesize' < 103 {
			di as text "Results table may be squished, try expanding Stata results window."
		}
    }

    di as text _n "------------------------------"
    di as text "   undid: Aggregate Results"
    di as text "------------------------------"
    di as text "Aggregation: `agg'"
    di as text "Weighting: `weights'"
    di as text "Aggregate ATT: " as result `agg_att'
    di as text "Standard error: " as result `agg_att_se'
    di as text "p-value: " as result `agg_att_pval'
    di as text "Jackknife SE: " as result `agg_att_jknife_se'
    di as text "Jackknife p-value: " as result `agg_att_jknife_pval'
    di as text "RI p-value: " as result ""

    return scalar att = `agg_att'
    return scalar se = `agg_att_se'
    return scalar p = `agg_att_pval'
    return scalar jkse = `agg_att_jknife_se'
    return scalar jkp = `agg_att_jknife_pval'
    // return scalar rip = `tmp_ri_pval_agg_att'[1]

    qui frame change default


end

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*0.0.1 - created function