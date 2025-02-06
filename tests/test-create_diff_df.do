clear all
set more off

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------create_diff_df------------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-02-06-----*/
/* exit 2: PASSING -------------------*/
/* exit 3: PASSING -------------------*/
/* exit 4: PASSING -------------------*/
/* exit 5: PASSING -------------------*/
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

* ---------------------------------------------- *
* Step 3: Try variations of create_diff_df
* make sure proper error messages display
* ensure outputted csv files and frames are correct
* ---------------------------------------------- *

create_diff_df , init_filepath("test_csv_files/init_vary_format_end.csv") date_format("yyyy") freq("yearly") 