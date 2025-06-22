clear all
set more off

/*------------------------------------*/
/*-----------TEST TEST TEST-----------*/
/*----------create_init_csv-----------*/
/*-----------TEST TEST TEST-----------*/
/*--------------PASSING---------------*/
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

* ---------------------------------------------- *
* Step 3: Try variations of create_init_csv
* make sure proper error messages display
* ensure outputted csv files and frames are correct
* ---------------------------------------------- *
undid_init , ///
    silo_names("71 58 64 59 85 57 72" ///
               " 61 34 88" ///
               " 11 12 13 14 15 16 21" ///
               " 22 23 31 32 33 35 41" ///
               " 42 43 44 45 46 47" ///
               " 51 52 53 54 55 56 62" ///
               " 63 73 74 81 82 83 84" ///
               " 86 87 91 92 93 94 95") ///
    start_times("1989") ///
    end_times("2000") /// match treatment times to appropriate silos in the same order 
    treatment_times("1991 1993 1996 1997 1997 1998 1998" ///
                    " 1999 2000 2000" ///
                    " control control control control control control control" ///
                    " control control control control control control control" ///
                    " control control control control control control" ///
                    " control control control control control control control" ///
                    " control control control control control control control" ///
                    " control control control control control control control") ///
    covariates("asian black male") ///
				   filepath("`c(pwd)'")
 
