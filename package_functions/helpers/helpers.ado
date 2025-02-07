/*------------------------------------*/
/*_parse_string_to_date*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-06 */
/*------------------------------------*/
cap program drop _parse_string_to_date
program define _parse_string_to_date
    version 16
    syntax varname(string) date_format(string) newvar(name)

    // Copy input to avoid modifying the original data
    gen str20 fixed_date = `varname'
    
    // Handle "yyyy" → Convert to "yyyy/01/01"
    if "`date_format'" == "yyyy" {
        replace fixed_date = fixed_date + "/01/01"
        local format_code "YMD"
    }

    // Handle "yyyym00" 
    else if "`date_format'" == "yyyym00" {
        replace fixed_date = substr(fixed_date,1,4) + "/" + substr(fixed_date, 6, .) + "/01"
        local format_code "YMD"
    }

    // Handle "yyyyddmm" (incorrect order) → Convert to "yyyy/mm/dd"
    else if "`date_format'" == "yyyyddmm" {
        replace fixed_date = substr(fixed_date,1,4) + "/" + substr(fixed_date,7,2) + "/" + substr(fixed_date,5,2)
        local format_code "YMD"
    }

    // Handle "yyyy/dd/mm" → Convert to "yyyy/mm/dd"
    else if "`date_format'" == "yyyy/dd/mm" {
        replace fixed_date = substr(fixed_date,1,4) + "/" + substr(fixed_date,9,2) + "/" + substr(fixed_date,6,2)
        local format_code "YMD"
    }

    // Handle "yyyy-dd-mm" → Convert to "yyyy/mm/dd"
    else if "`date_format'" == "yyyy-dd-mm" {
        replace fixed_date = substr(fixed_date,1,4) + "/" + substr(fixed_date,9,2) + "/" + substr(fixed_date,6,2)
        local format_code "YMD"
    }

    // Handle common formats that Stata supports directly
    else {
        local format_code "`date_format'"
    }

    // Convert to a Stata date using date()
    gen `newvar' = date(fixed_date, "`format_code'")

    // Apply readable Stata date format
    format `newvar' %td

    // Clean up temporary variable
    drop fixed_date

end



/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function