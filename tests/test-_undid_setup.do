clear all
set more off

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
* Step 3: Check that the macros have been created 
* ---------------------------------------------- *
_undid_env

if strpos("$UNDID_DATE_FORMATS", "ddmonyyyy") {
    di as result "Test Passed! 'ddmonyyyy' found in UNDID_DATE_FORMATS"
}
else {
    di as error "Test Failed! Could not find 'ddmonyyyy' in UNDID_DATE_FORMATS!"
}
if strpos("$UNDID_STAGGERED_COLUMNS", "gvar") {
    di as result "Test Passed! 'gvar' found in UNDID_DATE_FORMATS"
}
else {
    di as error "Test Failed! Could not find 'gvar' in UNDID_DATE_FORMATS!"
}

