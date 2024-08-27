{smcl}
{* *! version 0.0.1 27aug2024}
{help undidjl:undidjl}
{hline}

{title:Title}

{pstd}
undidjl - Stata wrapper for the Undid.jl Julia package{p_end}

{title:Description}

{pstd}
{cmd:undidjl} provides a Stata interface for interacting with the Undid.jl package, a Julia package used for computing difference-in-differences with unpoolable data. This wrapper facilitates the installation, version checking, and basic interaction with Undid.jl from within Stata.{p_end}

{title:Syntax}

{phang}
{cmd:checkundidversion}

{title:Command Description}

{phang}
{cmd:checkundidversion} checks if the Undid.jl Julia package is installed and reports the currently installed version. If it is not installed, the command installs the most recent version from {browse "https://github.com/ebjamieson97/Undid.jl"}.

{title:Options}

{phang}
There are no options for the {cmd:checkundidversion} command.

{title:Examples}

{pstd}Check the version of Undid.jl:

{phang2}{cmd:. checkundidversion}

{phang2}
This command will display the currently installed version of the Undid.jl package, or install it if it is not yet installed.

{title:Stored results}

{pstd}
{cmd:checkundidversion} stores the following in {cmd:r()}:

{synoptset 20 tabbed}
{synopthdr}
{synoptline}
{synopt:{cmd:r(undidjl_version)}}The current version of the Undid.jl package installed.{p_end}

{title:Author}

{pstd}
Eric Jamieson{p_end}

{pstd}
For more information about Undid.jl, visit the {browse "https://github.com/ebjamieson97/undidjl"} GitHub repository.{p_end}

{title:Citation}

{pstd}
{cmd:undidjl} is not an official Stata command. It is a free contribution to the research community.{p_end}
