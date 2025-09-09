/*------------------------------------*/
/*undid_plot*/
/*written by Eric Jamieson */
/*version 0.0.1 2025-09-02 */
/*------------------------------------*/
cap program drop undid_plot
program define undid_plot
    version 16
    syntax, dir_path(string) /// 
            [agg(string) weights(int 1) covariates(int 0) omit_silos(string) include_silos(string)]

    // ---------------------------------------------------------------------------------------- //
    // ---------------------------- PART ONE: Basic Input Checks ------------------------------ // 
    // ---------------------------------------------------------------------------------------- //

    if "`agg'" == "" {
        local agg "agg"
    }
    if !inlist("`agg'", "agg", "dis", "event", "silo") {
        di as error "'agg' must be set to one of: 'agg', 'dis', 'event', or 'silo'."
        exit 2
    }

    if !inlist(`weights', 0, 1) {
        di as error "'weights' must be set to either 1 (true) or 0 (false)."
        exit 3
    }

    if !inlist(`covariates', 0, 1)  {
        di as error "'covariates' must be set to either 1 (true) or 0 (false)."
        exit 4
    }

    local files : dir "`dir_path'" files "trends_data_*.csv"
    local nfiles : word count `files'
    if `nfiles' == 0 {
        display as error "No trends_data_*.csv files found in `dir_path'"
        exit 5
    }


    // ---------------------------------------------------------------------------------------- //
    // -------------------------------- PART TWO: Read In Data -------------------------------- // 
    // ---------------------------------------------------------------------------------------- //

    // Read in data
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

    // Omit or restrict based on omit_silos and include_silos options
    local omit_toggled = 0
    local include_toggled = 0
    if "`omit_silos'" != "" {
        local nsilo_omit : list sizeof omit_silos
        local omit_toggled = 1
    }
    if "`include_silos'" != "" {
        local nsilo_include : list sizeof include_silos
        local include_toggled = 1
    }
    if `include_toggled' == 1 & `omit_toggled' == 1 {
        local overlap : list omit_silos & include_silos
        if "`overlap'" != "" {
            di as error "The following silos appear in both 'omit_silos' and 'include_silos': `overlap'"
            exit 6
        }
    }
    qui levelsof silo_name, local(data_silos) clean
    if `omit_toggled' == 1 {
        local missing_omit ""
        foreach omit_silo of local omit_silos {
            local found = 0
            foreach data_silo of local data_silos {
                local clean_data_silo = subinstr(`"`data_silo'"', `"""', "", .)
                if "`omit_silo'" == "`clean_data_silo'" {
                    local found = 1
                    continue, break
                }
            }
            if `found' == 0 {
                local missing_omit "`missing_omit' `omit_silo'"
            }
        }
        if "`missing_omit'" != "" {
            di as error "The following silos in 'omit_silos' do not exist in the data: `missing_omit'"
            di as error "Available silos in data: `data_silos'"
            exit 7
        }
    }
    if `include_toggled' == 1 {
        local missing_include ""
        foreach include_silo of local include_silos {
            local found = 0
            foreach data_silo of local data_silos {
                local clean_data_silo = subinstr(`"`data_silo'"', `"""', "", .)
                if "`include_silo'" == "`clean_data_silo'" {
                    local found = 1
                    continue, break
                }
            }
            if `found' == 0 {
                local missing_include "`missing_include' `include_silo'"
            }
        }
        if "`missing_include'" != "" {
            di as error "The following silos in 'include_silos' do not exist in the data: `missing_include'"
            di as error "Available silos in data: `data_silos'"
            exit 8
        }
    }
    if `include_toggled' == 1 {
        local keep_condition ""
        foreach include_silo of local include_silos {
            if "`keep_condition'" == "" {
                local keep_condition `"silo == "`include_silo'""'
            }
            else {
                local keep_condition `"`keep_condition' | silo == "`include_silo'""'
            }
        }
        qui keep if `keep_condition'
    }
    if `omit_toggled' == 1 {
        local drop_condition ""
        foreach omit_silo of local omit_silos {
            if "`drop_condition'" == "" {
                local drop_condition `"silo != "`omit_silo'""'
            }
            else {
                local drop_condition `"`drop_condition' & silo != "`omit_silo'""'
            }
        }
        qui keep if `drop_condition'
    }

    // Additional processing for event plot
    if "`agg'" == "event" {
        qui keep if treatment_time != "control"
        local date_format = date_format[1]
        qui _parse_string_to_date, varname(treatment_time) date_format("`date_format'") newvar(gvar_date)
        qui _parse_string_to_date, varname(time) date_format("`date_format'") newvar(t)
        qui gen double event_time = .
        qui gen freq_n = real(word(freq, 1))
        qui gen freq_unit = lower(word(freq, 2))
        if substr(freq_unit, 1, 3) == "yea" {
            qui replace event_time = floor((year(t) - year(gvar_date)) / freq_n)
        }
        else if substr(freq_unit, 1, 3) == "mon" {
            qui replace event_time = floor((ym(year(t),  month(t)) - ym(year(gvar_date), month(gvar_date))) / freq_n)
        }
        else if substr(freq_unit, 1, 3) == "wee" {
            qui replace event_time = floor((t - gvar_date) / (7 * freq_n))
        }
        else if substr(freq_unit, 1, 3) == "day" { 
            qui replace event_time = floor((t - gvar_date) / freq_n)
        }
        qui drop freq_n
        qui drop freq_unit
    }

    // Select mean_outcome or mean_outcome_residualized based on covariates option
    if `covariates' == 0 {
        qui gen double y =  real(mean_outcome)
    }
    else if `covariates' == 1 {
        qui replace mean_outcome_residualized = "" if mean_outcome_residualized == "NA" | mean_outcome_residualized == "missing"
        qui gen double y = real(mean_outcome_residualized)
        qui count if missing(y)
        if r(N) > 0 {
            di as err "Error: Values of mean_outcome_residualized are missing, try setting covariates(0)."
            exit 9
        }
    }
    qui format y %20.15g

    if `weights' == 1 {
        qui replace n = "" if n == "NA" | n == "missing"
        qui destring n, replace
        qui count if missing(n)
        if r(N) > 0 {
            qui levelsof silo_name if missing(n), local(missing_silos) clean
            di as error "Error: Missing values of n for weights for the following silos: `missing_silos'"
            exit 10
        }
    }
   
    // cap frame drop filtered_data  
    // frame copy `temploadframe' filtered_data
    // qui frame change filtered_data
    // browse

    // ---------------------------------------------------------------------------------------- //
    // -------------------------------- PART THREE: ............ ------------------------------ // 
    // ---------------------------------------------------------------------------------------- //



end 

/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*0.0.1 - created function