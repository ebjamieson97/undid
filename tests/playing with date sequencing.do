frame change default
frame drop seq_frame
clear
import delimited "test_csv_files/init_staggered.csv", clear stringcols(_all)

local date_format = "yyyy"

    _parse_string_to_date, varname(start_time) date_format("yyyy") newvar(start_time_date)
    _parse_string_to_date, varname(end_time) date_format("yyyy") newvar(end_time_date)
_parse_string_to_date, varname(treatment_time) date_format("yyyy") newvar(treatment_time_date) 

cap confirm variable covariates 
if _rc {
	local covariates = "none"
}
else {
	local covariates = covariates[1]
}

local start_time_date = start_time_date[1]
local end_time_date = end_time_date[1]

frame create seq_frame str20 silo_name gvar t pre treat RI

local freq_string = "1 year"

// Extract numeric value and unit from freq_string
local num = real(word("`freq_string'", 1))
local unit = word("`freq_string'", 2)

// Define the increment correctly
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

// Loop through each `silo_name` to generate sequences
levelsof silo_name if treatment_time != "control", local(treated_silos)
levelsof silo_name if treatment_time == "control", local(control_silos)

foreach silo of local treated_silos {
    // Get unique treatment times (gvar) for the silo (excluding "control")
    levelsof treatment_time_date if silo_name == "`silo'", local(gvar_list)

    foreach gvar of local gvar_list {
        local gvar_num = `gvar' // store gvar
        
        // Get the corresponding end time safely
        qui summarize end_time_date if silo_name == "`silo'", meanonly
        local end_date = r(min)  // Extract the minimum (should be one unique value)
        
        // Generate date sequences
        local current = `gvar_num'
		
		if "`unit'" == "months" | "`unit'" == "month" {
 local pre_month = month(`current') - `num'
    local pre_year = year(`current')
    
    // Adjust for out-of-range months (e.g., month <= 0)
    while `pre_month' <= 0 {
        local pre_month = `pre_month' + 12
        local pre_year = `pre_year' - 1
    }

    // Generate valid pre-date
    local pre = mdy(`pre_month', min(day(`current'), day(mdy(`pre_month', 1, `pre_year'))), `pre_year')
		}
		else if "`unit'" == "years" | "`unit'" == "year" {
			local pre = mdy(month(`current'), day(`current'), year(`current') - `num')
		}
		else {
			local pre = `current' - `increment'
		}

        while `current' <= `end_date' {
            frame post seq_frame ("`silo'") (`gvar_num') (`current') (`pre') (1) (0)
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
					}
					else if `next_month' <= 12 {
                        local proposed_day = day(mdy(month(`current') + `num', day(`current'), year(`current')))
                        local proposed_day_minus_one = day(mdy(month(`current') + `num', day(`current') - 1, year(`current')))
                        local proposed_day_minus_two = day(mdy(month(`current') + `num', day(`current') - 2, year(`current')))
                        local proposed_day_minus_three = day(mdy(month(`current') + `num', day(`current') - 3, year(`current')))
                        local day_final = max(`proposed_day', `proposed_day_minus_one', `proposed_day_minus_two', `proposed_day_minus_three')
						local current = mdy(month(`current') + `num', day(`current'), year(`current'))
					}
				}
				else if "`unit'" == "years" | "`unit'" == "year" {
					local current = mdy(month(`current'), day(`current'), year(`current') + `num')
				}
				else {
					local current = `current' + `increment'
				}
        }
    }
}


// Switch to the new frame and format the dates
frame change seq_frame
format t %td
format gvar %td
format pre %td
gen unique_flag = .
bysort gvar t (silo_name): replace unique_flag = (_n == 1) 
sort silo_name gvar t 

foreach silo of local treated_silos {
	levelsof gvar if silo_name == "`silo'", local(silo_gvar)
	levelsof gvar if silo_name != "`silo'" & gvar != `silo_gvar', local(ri_gvars)
	foreach ri_gvar of local ri_gvars {
        // Get all unique (t, pre) combinations for the given gvar
        levelsof t if gvar == `ri_gvar' & silo_name != "`silo'", local(t_list)
        levelsof pre if gvar == `ri_gvar' & silo_name != "`silo'", local(pre_list)

        foreach t_val of local t_list {
            foreach pre_val of local pre_list {
                // Append new row with RI = 1, treat = -1, unique_flag = 0
                frame post seq_frame ("`silo'") (`ri_gvar') (`t_val') (`pre_val') (-1) (1) (0)
            }
        }
    }
}

// Add the control silos
preserve
    // Keep only rows where unique_flag == 1
    keep if unique_flag == 1

    // Keep only the required columns
    keep gvar t pre unique_flag

    // Store base dataset to be duplicated
    tempname base_data
    save `base_data', replace

    // Create an empty dataset to accumulate new rows
    tempfile new_rows
    save `new_rows', emptyok replace

    // Loop over each control silo and append data
    foreach silo of local control_silos {
        use `base_data', clear  // Reload the base data
        gen silo_name = "`silo'"   // Assign the current control silo
        gen RI = 0
        gen treat = 0
        replace unique_flag = 0  // Will be removed later

        append using `new_rows'  // Append new rows to growing dataset
        save `new_rows', replace // Save updated dataset
    }

    // Restore original dataset and append the new rows
restore
append using `new_rows'
drop if missing(silo_name)
drop unique_flag

// Add start_time and end_time
gen start_t = `start_time_date'
gen end_t =  `end_time_date'
_parse_date_to_string, varname(start_t) date_format("yyyy-mm-dd") newvar(start_time)
_parse_date_to_string, varname(end_t) date_format("yyyy-mm-dd") newvar(end_time)
drop start_t
drop end_t

// Add gt and diff_times
_parse_date_to_string, varname(gvar) date_format("`date_format'") newvar(gvar_str)
_parse_date_to_string, varname(t) date_format("`date_format'") newvar(t_str)
_parse_date_to_string, varname(pre) date_format("`date_format'") newvar(pre_str)
egen gt = concat(gvar_str t_str), punct(;)
egen diff_times = concat(t_str pre_str), punct(;)
tostring gvar, replace
replace gvar = gvar_str
drop t pre gvar_str t_str pre_str 

// Add freq, date_format, covariates, diff estimates and variances and reorder
gen freq = "`freq_string'"
gen date_format = "`date_format'"
gen covariates = "`covariates'"
qui gen diff_estimate = "NA"
qui gen diff_var = "NA"
qui gen diff_estimate_covariates = "NA"
qui gen diff_var_covariates = "NA"

qui order silo_name gvar treat diff_times gt RI start_time end_time diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq


