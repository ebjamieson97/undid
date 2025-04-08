{smcl}
{* *! version 1.0.0 08apr2025}
{help undid_stage_three:undid_stage_three}
{hline}

{title:undid}

{pstd}
undid - Estimate difference-in-differences with unpoolable data. {p_end}

{title:Command Description}  

{phang}
{cmd:undid_stage_three} Takes in all of the filled diff df CSV files and uses them to compute group level ATTs as well as the aggregate ATT and its standard errors and p-values.
 dir_path(string) agg(string) /// 
            [weights(int 1) covariates(int 0) imputation(string) save_csv(int 0) ///
            filename(string) filepath(string) nperm(int 1001) verbose(int 1)]
Required parameters:

- {bf:dir_path} : A string specifying the filepath to the directory (folder) where all of the filled diff CSV files for this analysis are stored.

- {bf:agg} : A string which specifies the aggregation methodology for computing the aggregate ATT in the case of staggered adoption. Options are:
    -> "silo", "g", or "gt". Defaults to "silo".

Optional parameters:

- {bf:weights} : Integer, either 1 (true) or 0 (false), which determines whether or not the weights should be used in the case of common adoption. Defaults to 1 (true).

- {bf:covariates} : Integer, either 1 (true) or 0 (false), which specifies whether to use the `diff_estimate` column or the `diff_estimate_covariates` column from the filled diff df CSV files when computing ATTs. Setting to 1 (true) selects the `diff_estimate_covariates` column and 0 (false) selects the `diff_estimate` column. Defaults to 0 (false).

- {bf:imputation} : A string specifying the imputation method to be used if there are missing `diff_estimate` or `diff_estimate_covariates` values in a staggered adoption setting. Options are:
    -> "linear_function"

- {bf:save_csv} : An integer value, either 1 (true) or 0 (false), which determines if a CSV copy of the UNDID results will be saved or not. Defaults to 0 (false).

- {bf:filename} : A string specifying the outputted filename. Must end in ".csv". Defaults to "UNDID_results.csv".

- {bf:filepath} : A string specifying the path to the folder in which to save the output file, e.g. "`c(pwd)'". Defaults to "`c(tempdir)'".

- {bf:nperm} : An integer specifying the number of unique random permutations to consider when performing the randomization inference. Defaults to 1001. 

- {bf:verbose} : An integer value, either 1 (true) or 0 (false), specifying if progress updates on the randomization inference procedure should be displayed. Defaults to 1 (true).

{title:Syntax}

{pstd}

{cmd:undid_stage_three} dir_path(string) agg(string) [{it:weights(int)} {it:covariates(int)} {it:imputation(string)} {it:save_csv(int)} {it:filename(string)} {it:filepath(string)} {it:nperm(int)} {it:verbose(int)}]{p_end}

{title:Examples}

{phang2}{cmd:undid_stage_three,}

{phang2} filler filler 

{title:Author}

{pstd}
Eric Jamieson{p_end}

{pstd}
For more information about undid, visit the {browse "https://github.com/ebjamieson97/undid"} GitHub repository.{p_end}

{title:Citation}

{pstd}
Please cite: Sunny Karim, Matthew D. Webb, Nichole Austin, Erin Strumpf. 2024. Difference-in-Differenecs with Unpoolable Data. {browse "https://arxiv.org/abs/2403.15910"} {p_end}