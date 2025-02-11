frame change default
clear
import delimited "test_csv_files/init_staggered.csv", clear stringcols(_all)

    _parse_string_to_date, varname(start_time) date_format("yyyy") newvar(start_time_date)
    _parse_string_to_date, varname(end_time) date_format("yyyy") newvar(end_time_date)
_parse_string_to_date, varname(treatment_time) date_format("yyyy") newvar(treatment_time_date) 

frame create seq_frame str20 silo_name gvar t pre treat RI

local freq_string = "40 months"

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
levelsof silo_name if treatment_time != "control", local(silo_list)

foreach silo of local silo_list {
    di as result "Processing silo: `silo'"
    di as result "unit: `unit'"
    // Get unique treatment times (gvar) for the silo (excluding "control")
    levelsof treatment_time_date if silo_name == "`silo'" & !missing(treatment_time_date), local(gvar_list)

    // If there are no valid treatment times, skip this silo
    if "`gvar_list'" == "" {
        di as error "Skipping silo `silo' (no valid treatment times)"
        continue
    }

    foreach gvar of local gvar_list {
        local gvar_num = real("`gvar'")  // Convert gvar to numeric
        
        // Get the corresponding end time safely
        qui summarize end_time_date if silo_name == "`silo'" & treatment_time_date == `gvar_num', meanonly
        local end_date = r(min)  // Extract the minimum (should be one unique value)
		di as result "This is the `end_date'"

        // Check if end_date is missing
        if missing(`end_date') {
            di as error "Skipping silo `silo', treatment time `gvar' (no valid end date)"
            continue
        }
        
        // Generate date sequences
        local current = `gvar_num'
		di as result "`unit'"
		
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
		di as result "`pre'"
		
        di as result "entering the while loop"
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

levelsof silo_name, local(treated_silos)
foreach silo of local silo_list {
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







