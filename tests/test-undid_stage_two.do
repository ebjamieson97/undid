clear all
set more off
version 16

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_two-----------*/
/*-----------TEST TEST TEST-----------*/
/*--------------UNTESTED---------------*/
/*-------version 1.0.0 2025-04-07-----*/
/*------------------------------------*/
/*EXITS 1 to 13: PASSING --------------*/


* ---------------------------------------------- *
* Step 1: Uninstall existing package (if installed)
* ---------------------------------------------- *
cap ado uninstall undid
if _rc == 0 {
    di as result "Existing undid package uninstalled."
} 

* ---------------------------------------------- *
* Step 2: Install development version of package from local directory
* ---------------------------------------------- *
local current_dir "`c(pwd)'"  // Store the current working directory (tests/)
cd ".."  // Move up one level to the package root
local pkg_path "`c(pwd)'"  // Store package root directory
cd "`current_dir'" // Go back to tests folder
cap net install undid, from("`pkg_path'") replace
if _rc {
    di as error "Failed to install undid package from `pkg_path'."
    exit 1
}



* ---------------------------------------------- *
* Step 3: Load in silo data and try variations of undid_stage_two
* make sure proper error messages display
* ensure outputted csv files are correct
* ---------------------------------------------- *
use "test_dta_files\State71.dta", clear
keep if year != 1992
tostring year, replace

undid_stage_two, empty_diff_filepath("test_csv_files\empty_diff_df_staggered.csv") silo_name("71") time_column(year) outcome_column(coll) silo_date_format("yyyy") filepath("`c(pwd)'") consider_covariates(0)



 
