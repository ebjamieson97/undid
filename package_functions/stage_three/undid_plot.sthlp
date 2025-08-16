{smcl}
{* *! version 0.0.1 16aug2025}
{help undid_stage_three:undid_plot}
{hline}

{title:undid}

{pstd}
undid - Estimate difference-in-differences with unpoolable data. {p_end}

{title:Command Description}  

{phang}
{cmd:undid_plot} Takes in all of the trends data CSV files and uses them to create parallel trends plots or event study plots.

Required parameters:

- {bf:dir_path} : A string specifying the filepath to the directory (folder) where all of the trends data CSV files for this analysis are stored.

Optional parameters:

- {bf:plot} : A string which specifies the type of plot to make. Options are:
    -> "agg", "dis", "silos", or "event". Defaults to "agg".

- {bf:weights} : Integer, either 1 (true) or 0 (false), which determines whether or not the weights should be used. Defaults to 1.

- {bf:covariates} : Integer, either 1 (true) or 0 (false), which specifies whether to use the `mean_outcome` column
or the `mean_outcome_residualized` column from the trends data CSV files while plotting. Setting to 0 (false) selects the `mean_outcome` column
and 1 (true) selects the `mean_outcome_residualized` column. Defaults to 0 (false).

- {bf:omit_silos} : A string, with different silo names separated by spaces, indicating any silos to omit from the plot.

- {bf:include_silos} : A string, with different silo names separated by spaces, indicating to only include these silos in the plot.

{title:Syntax}

{pstd}

{cmd:undid_plot} dir_path(string) [{it:plot(string)} {it:weights(int)} {it:covariates(int)}]{p_end}

{title:Author}

{pstd}
Eric Jamieson{p_end}

{pstd}
For more information about undid, visit the {browse "https://github.com/ebjamieson97/undid"} GitHub repository.{p_end}

{title:Citation}

{pstd}
Please cite: Sunny Karim, Matthew D. Webb, Nichole Austin, Erin Strumpf. 2024. Difference-in-Differenecs with Unpoolable Data. {browse "https://arxiv.org/abs/2403.15910"} {p_end}