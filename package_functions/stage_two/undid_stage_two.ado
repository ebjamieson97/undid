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

    // Grab empty_diff date format
    local empty_diff_date_format = date_format[1]

    // Convert diff_estimate, diff_var, diff_estimate_covariates, and diff_var_covariates in to numeric (double) columns with maximum precision
    foreach var in diff_estimate diff_var diff_estimate_covariates diff_var_covariates {
        qui replace `var' = "" if `var' == "NA" | `var' == "missing"
        qui destring `var', replace
        qui gen double `var'_tmp = `var'
        qui drop `var'
        qui gen double `var' = `var'_tmp
        qui drop `var'_tmp
        qui format `var' %20.15g
    }

    // Convert weight column (if it exists) to a double and store the weighting method for later, also grab some info for trends_data
    if `check_common' == 1 {
        local weight = lower(weights[1])
        qui replace weights = ""
        qui destring weights, replace
        qui gen double weights_tmp = weights
        qui drop weights
        qui gen weights = weights_tmp
        qui drop weights_tmp
        qui format weights %20.15g
        if treat[1] == "0" {
            local treatment_time_trends "control"
        }
        else if treat[1] == "1" {
            local treatment_time_trends = common_treatment_time[1]
        }
    }

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
        qui _parse_string_to_date, varname(start_time) date_format("yyyy-mm-dd") newvar(start_date)
        qui _parse_string_to_date, varname(end_time) date_format("yyyy-mm-dd") newvar(end_date)
        local end_date = end_date[1]
        local start_date = start_date[1]
        qui levelsof common_treatment_time, local(common_treatment_local) clean
        local cmn_trt_time = word("`common_treatment_local'", 1)
        qui levelsof date_format, local(date_formats) clean
        local diff_df_date_format = word("`date_formats'", 1)
        qui _parse_string_to_date, varname(common_treatment_time) date_format("`diff_df_date_format'") newvar(cmn_trt_date)
        qui summarize cmn_trt_date
        local trt_date = r(min)
        qui drop cmn_trt_date
        qui frame change default
        tempvar start_date_fixed
        gen `start_date_fixed' = real("`start_date'")
        tempvar end_date_fixed
        gen `end_date_fixed' = real("`end_date'")
        tempvar date
        tempvar trt_indicator
        qui _parse_string_to_date, varname(`time_column') date_format("`silo_date_format'") newvar(`date')
        qui gen `trt_indicator' = (`date' >= `trt_date')
        qui count if `trt_indicator' == 0
        local count_0 = r(N)
        qui count if `trt_indicator' == 1
        local count_1 = r(N)
        if `count_0' == 0 | `count_1' == 0 {
            di as error "Error: The local silo must have at least one obs before and after (or at) `cmn_trt_time'."
            exit 13
        }
        if "`weight'" == "standard" {
            local weight_val = `count_1' / (`count_1' + `count_0')
        }
        else {
            di as error "Error: weight indicated in empty_diff_df.csv must be one of: standard"
            exit 14
        }
        qui regress `outcome_column' `trt_indicator' if `date' >= `start_date_fixed' & `date' <= `end_date_fixed', robust
        local diff_estimate = _b[`trt_indicator']
        local diff_var = e(V)[1,1]

        // Compute diff_estimate_covariates and diff_var_covariates
        if "`covariates'" != "none" {
            qui regress `outcome_column' `trt_indicator' `covariates' if `date' >= `start_date_fixed' & `date' <= `end_date_fixed', robust
            local diff_estimate_covariates = _b[`trt_indicator']
            local diff_var_covariates = e(V)[1,1]
        }

        // Store values and write filled_diff_df CSV
        qui frame change `diff_df'
        qui replace diff_estimate = `diff_estimate'
        qui replace diff_var = `diff_var'
        qui replace weights = `weight_val'
        if "`covariates'" != "none" {
            qui replace diff_estimate_covariates = `diff_estimate_covariates'
            qui replace diff_var_covariates = `diff_var_covariates'
        }
        else if "`covariates'" == "none" {
            qui tostring diff_estimate_covariates, replace
            qui tostring diff_var_covariates, replace
            qui replace diff_estimate_covariates = "NA"
            qui replace diff_var_covariates = "NA"
        }
        qui order silo_name treat common_treatment_time start_time end_time weights diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq
        qui export delimited using "`fullpath_diff'", replace datafmt

        // Start date matching procedure for trends_data
        local freq_string = freq[1]
        
        // Define date increments
        local num = real(word("`freq_string'", 1))
        local unit = word("`freq_string'", 2)
        local increment = .
        if "`unit'" == "weeks" | "`unit'" == "week" {
            local increment = 7 * `num'
        } 
        else if "`unit'" == "months" | "`unit'" == "month" {
            local increment = .
        } 
        else if "`unit'" == "years" | "`unit'" == "year" {
            local increment = .
        } 
        else if "`unit'" == "days" | "`unit'" == "day"{
            local increment = `num'
        }

        // Loop through dates from start to one period past end time to create local of dates to be used for trends_data
        local list_of_dates ""
        local current = start_date[1]
        local list_of_dates "`list_of_dates' `current'"
        while `current' <= `end_date' {
            // Handle different units
    		if "`unit'" == "months" | "`unit'" == "month" {
    		    local next_month = month(`current') + `num'
    		    local year_adj = floor(`next_month'/12)
    		    if `next_month' > 12 {
                    local proposed_day = day(mdy(month(`current') + `num' - 12*`year_adj', day(`current'), year(`current') + `year_adj'))
                    local proposed_day_minus_one = day(mdy(month(`current') + `num' - 12*`year_adj', day(`current') - 1, year(`current') + `year_adj'))
                    local proposed_day_minus_two = day(mdy(month(`current') + `num' - 12*`year_adj', day(`current') - 2, year(`current') + `year_adj'))
                    local proposed_day_minus_three = day(mdy(month(`current') + `num' - 12*`year_adj', day(`current') - 3, year(`current') + `year_adj'))
                    local day_final = max(`proposed_day', `proposed_day_minus_one', `proposed_day_minus_two', `proposed_day_minus_three')
    		    	local current = mdy(month(`current') + `num' - 12*`year_adj', `day_final', year(`current') + `year_adj')
                    local list_of_dates "`list_of_dates' `current'"
    		    }
    		    else if `next_month' <= 12 {
                    local proposed_day = day(mdy(month(`current') + `num', day(`current'), year(`current')))
                    local proposed_day_minus_one = day(mdy(month(`current') + `num', day(`current') - 1, year(`current')))
                    local proposed_day_minus_two = day(mdy(month(`current') + `num', day(`current') - 2, year(`current')))
                    local proposed_day_minus_three = day(mdy(month(`current') + `num', day(`current') - 3, year(`current')))
                    local day_final = max(`proposed_day', `proposed_day_minus_one', `proposed_day_minus_two', `proposed_day_minus_three')
    		        local current = mdy(month(`current') + `num', day(`current'), year(`current'))
                    local list_of_dates "`list_of_dates' `current'"
    		    }
    		}
    		else if "`unit'" == "years" | "`unit'" == "year" {
    			local current = mdy(month(`current'), day(`current'), year(`current') + `num')
                local list_of_dates "`list_of_dates' `current'"
    		}
    		else {
    			local current = `current' + `increment'
                local list_of_dates "`list_of_dates' `current'"
    		}
        }

        // Match dates from the local silo to the most recently passed date in the list_of_dates local
        qui frame change default
        qui tempvar matched_date
        qui gen `matched_date' = .
        foreach date_str of local list_of_dates {
            tempvar temp_date
            qui gen `temp_date' = real("`date_str'")
            qui replace `matched_date' = `temp_date' if `temp_date' <= `date' & (`matched_date' < `temp_date' | `matched_date' == .)
        }

        // Compute trends_data
        // Initialize locals
        local mean_outcome_trends
        if "`covariates'" != "none" {
            local mean_outcome_resid_trends
        }

        // Compute conditional means
        qui levelsof `matched_date', local(matched_dates) clean
        foreach m_date of local matched_dates {
            qui summarize `outcome_column' if `matched_date' == `m_date'
            qui local mean_outcome = r(mean)
            local mean_outcome_trends "`mean_outcome_trends' `mean_outcome'"
            if "`covariates'" != "none" {
                qui reg `outcome_column' `covariates' if `matched_date' == `m_date', noconstant
                tempvar resid_trends
                qui predict double `resid_trends' if `matched_date' == `m_date', residuals
                qui summarize `resid_trends'
                qui local mean_outcome_resid = r(mean)
                qui drop `resid_trends'
                local mean_outcome_resid_trends "`mean_outcome_resid_trends' `mean_outcome_resid'"
            }
        }

        // Create trends frame
        if "`covariates'" == "none" {
            tempname trends_frame
            qui cap frame drop `trends_frame'
            qui frame create `trends_frame' ///
            strL silo_name ///
            strL treatment_time ///
            double time_numeric int ///
            double mean_outcome /// 
            strL mean_outcome_residualized ///
            strL covariates ///
            strL date_format ///
            strL freq
        }
        else if "`covariates'" != "none"{
            tempname trends_frame
            qui cap frame drop `trends_frame'
            qui frame create `trends_frame' ///
            strL silo_name ///
            strL treatment_time ///
            double time_numeric int ///
            double mean_outcome /// 
            double mean_outcome_residualized ///
            strL covariates ///
            strL date_format ///
            strL freq
        }
        
        // Populate trends frame
        qui frame change `trends_frame'
        local N : word count `matched_dates'
        local covariates = subinstr("`covariates'", " ", ";", .)
        forvalues i = 1/`N' {
            local time : word `i' of `matched_dates'
            local mean_outcome : word `i' of `mean_outcome_trends'
            if "`covariates'" == "none" {
                qui frame post `trends_frame' ("`silo_name'") ("`treatment_time_trends'") (`time') (`mean_outcome') ("NA") ("`covariates'") ("`empty_diff_date_format'") ("`freq_string'")
            }
            else if "`covariates'" != "none" {
                local mean_outcome_resid : word `i' of `mean_outcome_resid_trends'
                qui frame post `trends_frame' ("`silo_name'") ("`treatment_time_trends'") (`time') (`mean_outcome') (`mean_outcome_resid') ("`covariates'") ("`empty_diff_date_format'") ("`freq_string'")
            }    
        }
        
        // Convert numeric time in the trends data to a readable format 
        qui _parse_date_to_string, varname(time_numeric) date_format("`empty_diff_date_format'") newvar(time)
        qui order silo_name treatment_time time mean_outcome mean_outcome_residualized covariates date_format freq
        qui drop time_numeric 

        // Write trends_data CSV file
        qui export delimited using "`fullpath_trends'", replace
        qui frame change default
        
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