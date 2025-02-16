clear all
set more off

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_two-----------*/
/*-----------TEST TEST TEST-----------*/
/*--------------UNTESTED---------------*/
/*-------version 1.0.0 2025-02-15-----*/
/*------------------------------------*/


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


gen asdf = .
gen fdsa = .
* ---------------------------------------------- *
* Step 3: Load in silo data and try variations of undid_stage_two
* make sure proper error messages display
* ensure outputted csv files are correct
* ---------------------------------------------- *
undid_stage_two, empty_diff_filepath("asdf") silo_name("asdf") ///
            time_column(asdf) outcome_column(fdsa) silo_date_format("asdf") ///
			consider_covariates(1)
 
