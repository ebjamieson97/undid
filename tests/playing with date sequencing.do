clear
import delimited "test_csv_files/init_staggered.csv", clear stringcols(_all)

    _parse_string_to_date, varname(start_time) date_format("ddmonyyyy") newvar(start_time_date)
    _parse_string_to_date, varname(end_time) date_format("ddmonyyyy") newvar(end_time_date)
_parse_string_to_date, varname(treatment_time) date_format("yyyy-mm-dd") newvar(treatment_time_date) 

clear
set obs 100
local freq_string = "1 day"
local treatment_time = date("1990-01-01", "YMD")
local end_date = date("1990-03-01", "YMD")

// Generate a variable to hold the date sequence
gen date_seq = .

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


local i = 1
local current = `treatment_time'

while `current' <= `end_date' & `i' <= _N {
    replace date_seq = `current' in `i'
    
    // Handle different units
    if "`unit'" == "months" | "`unit'" == "month" {
        local current = mdy(month(`current') + `num', day(`current'), year(`current'))
    }
    else if "`unit'" == "years" | "`unit'" == "year" {
        local current = mdy(month(`current'), day(`current'), year(`current') + `num')
    }
    else {
        local current = `current' + `increment'
    }
    
    local i = `i' + 1
}

gen date_seq_str = strofreal(date_seq, "%tdYYYY-MM-DD")
gen date_seq_str2 = string(date_seq, "%td")