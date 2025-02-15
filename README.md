# undid
A framework for estimating difference-in-differences with unpoolable data, based on [Karim, Webb, Austin, and Strumpf (2024)](https://arxiv.org/abs/2403.15910v2). Supports common or staggered adoption, multiple groups, and the inclusion of covariates. Also computes p-values for the aggregate average treatment effect on the treated via the randomization inference procedure described in [MacKinnon and Webb (2020)](https://doi.org/10.1016/j.jeconom.2020.04.024).

![undid schematic](./images/undid_schematic.png)

## Installation
```stata
net install undid, from("https://raw.githubusercontent.com/ebjamieson97/undid/main/")
```
### Update
```stata
ado uninstall undid
net install undid, from("https://raw.githubusercontent.com/ebjamieson97/undid/main/")
```

## Requirements
* **Stata**: Version 16 or later

## Stage One: Initialize

#### `create_init_csv` - Creates an initial CSV file (`init.csv`) and displays its filepath

Generates an initial CSV file (`init.csv`) specifying the silo names, start times, end times, and treatment times. This file is then used to create the `empty_diff_df.csv`, which is to be sent to each silo.

Control silos should be marked with `"control"` in the `treatment_times` argument.

Covariates may be specified when calling `create_init_csv` or when calling `create_diff_df`.

Ensure that dates are all entered in the same date format, a list of compatible date formats can be seen [here.](#compatible-date-formats)

**Parameters:**

- **silo_names** (*string*):  
  A string specifying the different silo names. Silo names should be separated by spaces, e.g. `silo_names("Ontario Quebec")`.
  
- **start_times** (*string*):  
  A string which indicates the starting time for the analysis at each silo.

- **end_times** (*string*):  
  A string which indicates the end time for the analysis at each silo.

- **treatment_times** (*string*):  
  A string which indicates the treatment time at each silo. Control silos should be labelled with the treatment time `"control"`.

- **covariates** (*string, optional*):  
  A string specifying covariates to be considered at each silo.

- **filename** (*string, optional*):  
  A string specifying the outputted filename. Must end in `.csv`. Defaults to `"init.csv"`.

- **filepath** (*string, optional*):  
  A string specifying the path to the folder in which to save the output file. e.g. `` "`c(pwd)'" ``. Defaults to `` "`c(tempdir)'" ``

```stata
* Using a subset of data from the merit scholarship example shown in https://arxiv.org/abs/2403.15910

create_init_csv, silo_names("71 73 58 46") start_times("1989") end_times("2000") treatment_times("1991 control 1993 control") covariates("asian black male")

init.csv saved to: C:\Users\ERICBR~1\AppData\Local\Temp\init.csv
```

#### `create_diff_df` - Creates the CSV file to be sent out to each silo (`empty_diff_df.csv`) and displays its filepath

Creates the `empty_diff_df.csv` which lists all of the differences that need to calculated at each silo in order to compute the aggregate ATT. The `empty_diff_df.csv` is then to be sent out to each silo to be filled out.

**Parameters:**

- **init_filepath** (*string*):  
  A string specifying the filepath to the `init.csv`.
  
- **date_format** (*string*):  
  A string which specifies the [date format](#compatible-date-formats) used in the `init.csv`. 

- **freq** (*string*):  
  A string which indicates the length of the time periods to be used when computing the differences in mean outcomes between periods at each silo and the length of a period for the trends data. Options are:
  - `year month week day years months weeks days`

- **covariates** (*string, optional*):  
  A string specifying covariates to be considered at each silo. If left blank uses covariates from `init.csv`. 

- **freq_multiplier** (*integer, optional*):  
  Specify if the frequency should be multiplied by a non-zero integer. For example, if the time periods to consider are two years, set `freq("years") freq_multiplier(2)`.

- **weights** (*string, optional*):
  A string indicating the type of weighting to use in the case of common adoption. Defaults to "standard". Options are:
  - "standard" weighs each silo according to: (num of obs after and at the treatment period) / (num of obs)

- **filename** (*string, optional*):  
  A string specifying the outputted filename. Must end in `.csv`. Defaults to `"init.csv"`.

- **filepath** (*string, optional*):  
  A string specifying the path to the folder in which to save the output file, e.g. `` "`c(pwd)'" ``. Defaults to `` "`c(tempdir)'" ``.

```stata
create_diff_df, filepath("C:/Users/User/Documents/Project Files/init.csv") date_format("yyyy") freq("year")

empty_diff_df.csv saved to: C:\Users\ERICBR~1\AppData\Local\Temp\empty_diff_df.csv
```


## Stage Two: Silos

#### 5. `undidjl_stage_two` - Creates an two .csv files (filled_diff_df_$silo_name.csv and trends_data_$silo_name.csv), displays their filepaths, and returns one .csv's contents to the active Stata dataset.

Based on the information given in the `empty_diff_df.csv`, computes the appropriate differences in mean outcomes at the local silo and saves as `filled_diff_df_$silo_name.csv`. 

Note that the `time_column` should reference a string variable. This is in order to facilitate passing date information between Stata and Julia. 

Further, covariates at the local silo should be renamed to match the spelling used in the `empty_diff_df.csv`. 

Ensure that the local silo data is loaded as Stata's active dataset before running `undidjl_stage_two`. 

**Parameters:**

- **filepath** (*string, required*):  
  A string specifying the filepath to the `empty_diff_df.csv`.
  
- **local_silo_name** (*string, required*):  
  A string which specifies the local silo's name as it is written in the `empty_diff_df.csv`. 

- **time_column** (*string, required*):  
  A string which indicates the name of the variable in the local silo data which contains the date information. This variable should be a string. 

- **outcome_column** (*string, required*):  
  A string specifying the name of the variable in the local silo data which contains the outcome of interest.

- **local_date_format** (*string, required*):  
  A string specifying the [date format](#compatible-date-formats) used in the `time_column` variable. 
  
- **consider_covariates** (*string, optional*):  
  A string which if set to `"false"` ignores computations involving the covariates specified in the `empty_diff_df.csv`. Defaults to `"true"`. 

- **view_dataframe** (*string, optional*):  
  Specify which dataframe should be passed back to Stata's active dataset. Either `"trends"` or `"diff"`. Defaults to `"diff"`.

```stata
* An analogous script would be run at each silo (71, 73, 58 and 46)
. use "C:\Users\User\Data\State73.dta", clear
. undidjl_stage_two, filepath("C:/Users/User/Documents/csvs/empty_diff_df.csv") local_silo_name("73") time_column("date_str") outcome_column("coll") local_date_format("ddmonyyyy") view_dataframe("trends")

filled_diff_df_73.csv saved to
C:/Users/User/Current Folder/filled_diff_df_73.csv
trends_data_73.csv saved to
C:/Users/User/Current Folder/trends_data_73.csv
```

## Stage Three: Analysis

#### 6. `undidjl_stage_three` - Computes and displays UNDID results (aggregate ATT, standard errors, p-values).

Takes in all of the `filled_diff_df_$silo_name.csv`'s and uses them to compute the aggregate ATT and standard errors. 

The `agg` parameter specifies the aggregation method used in the case of staggered adoption. By default it is set to `"silo"` so that the ATTs are aggregated across silos with each silo having equal weight, but can be set to `"gt"` or `"g"` instead. Aggregating across `"g"` calculates ATTs for groups based on when the treatment time was, with each `"g"` group having equal weight. Aggregating across `"gt"` calculates ATTs for groups based on when the treatment time was and the time for which the ATT is calculated. This `agg` parameter is ignored in the case of a common treatment time and only takes effect in the case of staggered adoption.

If errors persist, check to see if there are missing values of `diff_estimates` in the `combined_diff_data.csv` and if so consider setting `interpolation = "linear_function"`. 

**Parameters:**

- **folder** (*string, required*):  
  A string specifying the filepath to the folder containing all of the `filled_diff_df_$silo_name.csv`'s.
  
- **agg** (*string, optional*):  
  A string which specifies the aggregation methodology for computing the aggregate ATT in the case of staggered adoption. Either `"silo"`, `"g"`, or `"gt"`. Defaults to `"silo"`.

- **covariates** (*string, optional*):  
  A string (either `"true"` or `"false"`) which specifies whether to use the `diff_estimate` or the `diff_estimate_covariates` column when computing the aggregate ATT. Defaults to `"false"`.

- **save_csv** (*string, optional*):  
  A string (either `"true"` or `"false"`) which determines whether or not to save the `combined_diff_data.csv`. Defaults to `"true"`.

- **interpolation** (*string, optional*):  
  A string (either `"false"` or `"linear_function"`) which specifies which, if any, method of interpolation/extrapolation for missing values of `diff_estimate` or `diff_estimate_covariates` should be used. Defaults to `"false"`. There must be at least one value for the (silo,g) group for which a missing value is being estimated in order for `"linear_function"` interpolation to work.

- **weights** (*string, optional*):
  A string (either "true" or "false") which determines whether or not the weights should be used in the case of common adoption. Defaults to "true".

```stata
. undidjl_stage_three, folder("C:/Users/User/Documents/Files From Silos") agg("g") covariates("true")

Saving combined_diff_data.csv to C:\Current Working Directory
Saving UNDID_results.csv to C:\Current Working Directory

-------------------------------------------------------------------------------------------
                                       UNDID Results                    
-------------------------------------------------------------------------------------------
g                         | ATT             | SE     | p-val  | JKNIFE SE  | JKNIFE p-val |
--------------------------|-----------------|--------|--------|------------|--------------|
1991                      |-0.0155456       | 0.033  | 0.642  | 0.031      | 0.624        |
--------------------------|-----------------|--------|--------|------------|--------------|
1993                      |0.1641971        | 0.031  | 0.000  | 0.027      | 0.000        |
--------------------------|-----------------|--------|--------|------------|--------------|
Aggregation: g
Aggregate ATT: .07432573
Standard error: .08987133
p-value: .56009382
Jackknife SE: .08987133
Jackknife p-value: .56009382
RI p-value: .5
```

#### 7. `plot_parallel_trends` - Plots parallel trends figures.

Combines all of the `trends_data_$silo_name.csv` files and uses this data to plot trends by silo or by treated/control status. 

**Parameters:**

- **folder** (*string, required*):  
  A string specifying the filepath to the folder containing all of the `trends_data_$silo_name.csv`'s.
  
- **outcome_variable** (*string, required*):  
  A string which is used as the title of plot.

- **silos** (*string, optional*):  
  A string which confines the plotting to the specified silos. 

- **save_csv** (*string, optional*):  
  A string (either `"true"` or `"false"`) which determines whether or not to save the `combined_trends_data.csv`. Defaults to `"true"`.

- **covariates** (*string, optional*):  
  A string (either `"true"` or `"false"`) which determines whether to plot the mean outcome or the mean outcome residualized by covariates. Defaults to `"false"` (plots the mean outcome). 

- **omit_silos** (*string, optional*):  
  A string which omits the specified silos from the plot.

- **date_format** (*string, optional*):  
  A string determining the format of the dates to appear on the x-axis of the plot. Options include:
  - `"yearly"` or `"%tdCCYY"`
  - `"monthly"` or `"%tdMonYY"`
  - `"full_date"` or `"%tdDD-NN-CCYY"`
  - `"day_and_month"` or `"%tdDDMon"`

- **combine** (*string, optional*):  
  A string (either `"true"` or `"false"`) which if set to `"true"` plots two lines: one line for the combined average across treated silos, and one line for the combined average across control silos. Otherwise plots every  silo individually. Defaults to "`false"`.

- **step** (*integer, optional*):  
  An integer for determining the number of periods between each date shown on the x-axis. Defaults to `1`. 

```stata
plot_parallel_trends, folder("C:/Users/User/Documents/Files From Silos") outcome_variable("College Attendance") date_format("yearly")
```
![Parallel trends plot with seperated silos](./images/silos46_58_71_73.png)
```stata
plot_parallel_trends, folder("C:/Users/User/Documents/Files From Silos") outcome_variable("College Attendance") date_format("yearly") combine("true")
```
![Parallel trends plot with silos combined as one control line and one treatment line](./images/silos46_58_71_73_combined.png)



### Appendix

#### Compatible Date Formats
- `ddmonyyyy` → 25aug1990
- `yyyym00` → 1990m8
- `yyyy/mm/dd` → 1990/08/25
- `yyyy-mm-dd` → 1990-08-25
- `yyyymmdd` → 19900825
- `yyyy/dd/mm` → 1990/25/08
- `yyyy-dd-mm` → 1990-25-08
- `yyyyddmm` → 19902508
- `dd/mm/yyyy` → 25/08/1990
- `dd-mm-yyyy` → 25-08-1990
- `ddmmyyyy` → 25081990
- `mm/dd/yyyy` → 08/25/1990
- `mm-dd-yyyy` → 08-25-1990
- `mmddyyyy` → 08251990
- `yyyy` → 1990

