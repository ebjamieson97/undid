clear all
set more off
version 16

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------undid_stage_three-----------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-05-04-----*/
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
* Step 3: Load in silo data and try variations of undid_stage_two
* make sure proper error messages display
* ensure outputted csv files are correct
* ---------------------------------------------- *
// show trace for up to, say, 3 levels of calls

set trace off
set tracedepth 1
// actually turn tracing on

undid_stage_three, dir_path("C:\\Users\\Eric Bruce Jamieson\\Documents\\Dalhousie Work\\undid\\tests\\test_csv_files\\stage_three\\staggered") weights("both")

set trace off



 
