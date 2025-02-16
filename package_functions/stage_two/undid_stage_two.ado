/*------------------------------------*/
/*undid_stage_two*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-15 */
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

    // Check consider_covariates
    if `consider_covariates' < 0 | `consider_covariates' > 1 {
        di as result "Error: consider_covariates must be set to 0 (false) to 1 (true)."
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