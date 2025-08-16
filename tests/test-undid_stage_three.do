clear all
set more off
version 16

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_three-----------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-08-16-----*/
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
    exit 2
}



* ---------------------------------------------- *
* Step 3: Load in silo data and try variations of undid_stage_three
* make sure proper error messages display
* ensure outputs are correct
* ---------------------------------------------- *
// show trace for up to, say, 1 levels of calls

clear
set trace off
set tracedepth 1

undid_stage_three, dir_path("test_csv_files\stage_three\common") agg("silo") weights("both") max_attempts(20) use_pre_controls(0) covariates(0) verbose(250) seed(123)
