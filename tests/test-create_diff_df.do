clear all
set more off

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------create_diff_df------------*/
/*-----------TEST TEST TEST-----------*/
/*-------version 1.0.0 2025-02-15-----*/
/* exit 2: PASSING -------------------*/
/* exit 3: PASSING -------------------*/
/* exit 4: PASSING -------------------*/
/* exit 5: PASSING -------------------*/
/* exit 6: PASSING -------------------*/
/* exit 7: PASSING -------------------*/
/* exit 8: PASSING -------------------*/
/* exit 9: PASSING -------------------*/
/* exit 10: PASSING ------------------*/
/* COVARIATE PROCESSING: PASSING -----*/
/* exit 11: PASSING ------------------*/
/* exit 12: PASSING ------------------*/
/* exit 13: PASSING ------------------*/
/* exit 14: PASSING ------------------*/
/* exit 15: PASSING ------------------*/
/* COMMON ADOPTION: PASSING ----------*/
/* STAGGERED ADOPTION: PASSING  ------*/



/*------------------------------------*/

* ---------------------------------------------- *
* Step 1: Uninstall existing package 
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

create_diff_df , init_filepath("test_csv_files\\") date_format("yyyy") freq("years") filepath("`c(pwd)'")