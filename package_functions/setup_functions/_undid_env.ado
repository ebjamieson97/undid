/*------------------------------------*/
/*_undid_env*/
/*written by Eric Jamieson */
/*version 1.0.0 2025-02-05 */
/*------------------------------------*/
cap program drop _undid_env
program define _undid_env
    version 16
    global UNDID_DATE_FORMATS "ddmonyyyy yyyym00 yyyy/mm/dd yyyy-mm-dd yyyymmdd yyyy/dd/mm yyyy-dd-mm yyyyddmm dd/mm/yyyy dd-mm-yyyy mm/dd/yyyy mm-dd-yyyy mmddyyyy yyyy"
    global UNDID_MONTH_DICT "jan:01 feb:02 mar:03 apr:04 may:05 jun:06 jul:07 aug:08 sep:09 oct:10 nov:11 dec:12"
    global UNDID_MONTH_DICT_REVERSE "1:jan 2:feb 3:mar 4:apr 5:may 6:jun 7:jul 8:aug 9:sep 10:oct 11:nov 12:dec"
    global UNDID_FREQ "year month week day years months weeks days"
    global UNDID_STAGGERED_COLUMNS "silo_name gvar treat diff_times gt diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq RI start_time end_time"
    global UNDID_COMMON_COLUMNS "silo_name treat common_treatment_time start_time end_time weights diff_estimate diff_var diff_estimate_covariates diff_var_covariates covariates date_format freq"
    global UNDID_INTERPOLATION_OPTIONS "linear_function nearest_value piecewise_linear"
    global UNDID_WEIGHTS "standard"
end
/*--------------------------------------*/
/* Change Log */
/*--------------------------------------*/
*1.0.0 - created function