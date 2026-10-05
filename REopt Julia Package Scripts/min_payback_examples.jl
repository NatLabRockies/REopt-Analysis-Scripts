"""
Examples for running minimum payback threshold optimization analysis using the REopt Julia Package.
"""

using REopt
using JSON
using JuMP
using Xpress
using XLSX
using DataFrames

include(joinpath(@__DIR__, "functions", "reopt_helpers.jl"))

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

    input_data_site["ElectricLoad"]["year"] = 2025

    # Add the rates
    input_data_site["ElectricTariff"]["blended_annual_energy_rate"] = blended_annual_energy_rate
    input_data_site["ElectricTariff"]["blended_annual_demand_rate"] = blended_annual_demand_rate
    input_data_site["ElectricTariff"]["wholesale_rate"] = 0.0 # $/kWh

    input_data_site["Settings"]["solver_name"] = "Xpress"

    # Add the financial parameters
    input_data_site["Financial"]["offtaker_tax_rate_fraction"] = 0.0
    input_data_site["Financial"]["owner_tax_rate_fraction"] = 0.0

    # Add in the PV system
    input_data_site["PV"] = Dict("location" => "ground", "installed_cost_per_kw" => 1500.0)  # Example PV system size in kW

    # Add in ElectricStorage to the json
    if i > 5
        input_data_site["ElectricStorage"] = Dict("model_degradation" => false, "battery_replacement_year" => 10)
    end

    println("About to start run for threshold: ", thresholds[i], " years.")

    # run the optimization
    #s = Scenario(input_data_site)
    println("Obtained Scenario()")
    inputs = REoptInputs(Scenario(input_data_site))
    println("Set up inputs part 1")
    bau_inputs = REopt.BAUInputs(inputs)
    println("Run the model part 1")
    m_bau = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
    println("Run through reopt part 1")
    r_bau = run_reopt(m_bau, bau_inputs)
    operating_cost_bau = r_bau["Financial"]["year_one_operating_cost_before_tax_model"]

    println("Now re-insert operating cost $operating_cost_bau and $(thresholds[i]) into input_data_site and re-run optimization.")
    # set the current threshold
    input_data_site["Financial"]["max_simple_payback_years"] = thresholds[i]
    input_data_site["Financial"]["bau_year_one_operating_cost"] = operating_cost_bau

    #s_opt = Scenario(input_data_site)
    inputs_opt = REoptInputs(Scenario(input_data_site))

    #m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MILREPSTOP" => 0.01, "OUTPUTLOG" => 0))
    m_opt = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
    println("Set up models")
    results = run_reopt(m_opt, inputs_opt)
    println("Obtained results")

    # Calculate proforma metrics
    proforma_metrics = proforma_results(inputs_opt, results)

    append!(site_analysis, [(input_data_site, results)])
    println("Completed run for simple payback threshold: ", thresholds[i], " years.")
end

file_storage_location = "results/"
write.(joinpath(file_storage_location, "min_payback_results.json"), JSON.json(site_analysis))

scens = thresholds

df = DataFrame(
    threshold_payback = [thresholds[i] for i in eachindex(scens)],
    payback_years = [safe_get(site_analysis[i][2], ["Financial", "simple_payback_years"]) for i in eachindex(scens)],
    npv = [round(safe_get(site_analysis[i][2], ["Financial", "npv"]), digits=2) for i in eachindex(scens)],
    lcc = [round(safe_get(site_analysis[i][2], ["Financial", "lcc"]), digits=2) for i in eachindex(scens)],
    lcc_BAU = [round(safe_get(site_analysis[i][2], ["Financial", "lcc_bau"]), digits=2) for i in eachindex(scens)],
    PV_size = [safe_get(site_analysis[i][2], ["PV", "size_kw"]) for i in eachindex(scens)],
    PV_all_year1_production = [round(safe_get(site_analysis[i][2], ["PV", "year_one_energy_produced_kwh"]), digits=0) for i in eachindex(scens)],
    PV_all_annual_energy_production_avg = [round(safe_get(site_analysis[i][2], ["PV", "annual_energy_produced_kwh"]), digits=0) for i in eachindex(scens)],
    PV_all_energy_lcoe = [round(safe_get(site_analysis[i][2], ["PV", "lcoe_per_kwh"]), digits=4) for i in eachindex(scens)],
    PV_all_serving_load = [sum(safe_get(site_analysis[i][2], ["PV", "electric_to_load_series_kw"], 0))* 0.25 for i in eachindex(scens)],
    PV_all_energy_exported = [round(safe_get(site_analysis[i][2], ["PV", "annual_energy_exported_kwh"]), digits=0) for i in eachindex(scens)],
    PV_all_energy_curtailed = [sum(safe_get(site_analysis[i][2], ["PV", "electric_curtailed_series_kw"], 0))* 0.25 for i in eachindex(scens)],
    PV_all_energy_to_Battery_year1 = [sum(safe_get(site_analysis[i][2], ["PV", "electric_to_storage_series_kw"], 0))* 0.25 for i in eachindex(scens)],
    Battery_size_kw = [safe_get(site_analysis[i][2], ["ElectricStorage", "size_kw"]) for i in eachindex(scens)],
    Battery_size_kwh = [safe_get(site_analysis[i][2], ["ElectricStorage", "size_kwh"]) for i in eachindex(scens)],
    Grid_Electricity_Supplied_kWh_annual = [round(safe_get(site_analysis[i][2], ["ElectricUtility", "annual_energy_supplied_kwh"]), digits=0) for i in eachindex(scens)],
    Grid_Electricity_Supplied_kWh_annual_bau = [round(safe_get(site_analysis[i][2], ["ElectricUtility", "annual_energy_supplied_kwh_bau"]), digits=0) for i in eachindex(scens)],
    LifeCycle_Emission_Reduction_Fraction = [safe_get(site_analysis[i][2], ["Site", "lifecycle_emissions_reduction_CO2_fraction"]) for i in eachindex(scens)],
    LifeCycle_capex_costs_for_generation_techs = [round(safe_get(site_analysis[i][2], ["Financial", "lifecycle_generation_tech_capital_costs"]), digits=2) for i in eachindex(scens)],
    LifeCycle_capex_costs_for_battery = [round(safe_get(site_analysis[i][2], ["Financial", "lifecycle_storage_capital_costs"]), digits=2) for i in eachindex(scens)],
    Initial_upfront_capex_wo_incentives = [round(safe_get(site_analysis[i][2], ["Financial", "initial_capital_costs"]), digits=2) for i in eachindex(scens)],
    Initial_upfront_capex_w_incentives = [round(safe_get(site_analysis[i][2], ["Financial", "initial_capital_costs_after_incentives"]), digits=2) for i in eachindex(scens)],
    Initial_upfront_battery_capex = [round(safe_get(site_analysis[i][2], ["ElectricStorage", "initial_capital_cost"]), digits=2) for i in eachindex(scens)],
    Present_cost_of_replacement_battery_after_tax = [round(safe_get(site_analysis[i][2], ["Financial", "replacements_present_cost_after_tax"]), digits=2) for i in eachindex(scens)],
    Year1_lifecycle_costs_om_before_tax = [safe_get(site_analysis[i][2], ["Financial", "year_one_om_costs_before_tax"]) for i in eachindex(scens)],
    Yr1_energy_cost_after_tax = [round(safe_get(site_analysis[i][2], ["ElectricTariff", "year_one_energy_cost_before_tax"]), digits=2) for i in eachindex(scens)],
    Yr1_demand_cost_after_tax = [round(safe_get(site_analysis[i][2], ["ElectricTariff", "year_one_demand_cost_before_tax"]), digits=2) for i in eachindex(scens)],
    Yr1_total_energy_bill_before_tax = [round(safe_get(site_analysis[i][2], ["ElectricTariff", "year_one_bill_before_tax"]), digits=2) for i in eachindex(scens)],
    Year1_elec_bill_before_tax_bau = [safe_get(site_analysis[i][2], ["ElectricTariff", "year_one_bill_before_tax_bau"]) for i in eachindex(scens)],
    Yr1_export_benefit_before_tax = [round(safe_get(site_analysis[i][2], ["ElectricTariff", "year_one_export_benefit_before_tax"]), digits=2) for i in eachindex(scens)],
    Yr1_total_operating_cost_before_tax = [round(safe_get(site_analysis[i][2], ["Financial", "year_one_total_operating_cost_before_tax"]), digits=2) for i in eachindex(scens)],
    IRR = [safe_get(site_analysis[i][2], ["Financial", "internal_rate_of_return"]) for i in eachindex(scens)]
)

# Define the xlsx loacation
xlsx_results_location = joinpath(file_storage_location, "min_payback_results.xlsx")

# Check if the Excel file already exists
if isfile(xlsx_results_location)
    # Open the Excel file in read-write mode
    XLSX.openxlsx(xlsx_results_location, mode="rw") do xf
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
    XLSX.openxlsx(xlsx_results_location, mode="w") do xf
        XLSX.rename!(xf[1], "Result_0")
        XLSX.writetable!(xf["Result_0"], df)
    end
end

println("Successful write into XLSX file: $xlsx_results_location")