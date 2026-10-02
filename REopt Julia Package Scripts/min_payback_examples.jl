"""
Examples for running minimum payback threshold optimization analysis using the REopt Julia Package.
"""

using REopt
using JSON
using JuMP
using HiGHS
using XLSX
using DataFrames

blended_annual_energy_rate = 0.12  # Example value in $/kWh
blended_annual_demand_rate = 35.0  # Example value in $/kW-month

# Different thresholds to test for minimum payback analysis
thresholds = [5, 10, 15, 20, 25, 5, 10, 15, 20, 25]

# Initialize an array to store the results for each site and threshold
site_analysis = []

# Will run multiple runs on the same site with different simple payback thresholds and once with PV only and the next with PV + BESS
for i in eachindex(thresholds)

    # read within the loop to ensure a fresh copy for each threshold
    input_data = JSON.parsefile("scenarios/min_payback.json")
    input_data_site = copy(input_data)

    # set the current threshold
    input_data_site["Financial"]["max_simple_payback_years"] = thresholds[i]

    # Add the rates
    input_data_site["Financial"]["blended_annual_energy_rate"] = blended_annual_energy_rate
    input_data_site["Financial"]["blended_annual_demand_rate"] = blended_annual_demand_rate

    # run the optimization
    s = Scenario(input_data_site)
    inputs = REoptInputs(s)

    m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01, "output_flag" => false, "log_to_console" => false))
    m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01,"output_flag" => false, "log_to_console" => false))

    results = run_reopt([m1,m2], inputs)
    append!(site_analysis, [(input_data_site, results)])
end

file_storage_location = "results/"
write.(joinpath(file_storage_location, "min_payback_results.json"), JSON.json(site_analysis))

# Define the xlsx loacation
xlsx_results_location = joinpath(file_storage_location, "min_payback_results.xlsx")

# Check if the Excel file already exists
if isfile(file_storage_location)
    # Open the Excel file in read-write mode
    XLSX.openxlsx(file_storage_location, mode="rw") do xf
        counter = 0
        while true
            sheet_name = "Result_" * string(counter)
            try
                sheet = xf[sheet_name]
                counter += 1
            catch
                break
            end
        end
        sheet_name = "Result_" * string(counter)
        # Add new sheet
        XLSX.addsheet!(xf, sheet_name)
        # Write DataFrame to the new sheet
        XLSX.writetable!(xf[sheet_name], df)
    end
else # if the XLSX file does not exist, create a new one and write the DataFrame to it
    # Write DataFrame to a new Excel file
    XLSX.openxlsx(file_storage_location, mode="w") do xf
        XLSX.rename!(xf[1], "Result_0")
        XLSX.writetable!(xf["Result_0"], df)
    end
end

println("Successful write into XLSX file: $file_storage_location")