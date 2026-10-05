# REopt Analysis Scripts for the REopt API and Julia Package

[REopt](https://reopt.nrel.gov/) is a techno-economic decision support model
from National Laboratory of the Rockies (NLR) which is used for optimizing energy systems for buildings, campuses,
communities, and microgrids. REopt can be accessed in many ways: 
- Free, easy to use web tool: https://reopt.nlr.gov/
- By calling the REopt application programming interface (API) (examples in this repository)
- By using the registered REopt Julia Package (examples in this repository)
  
This repository includes useful guidance and example scripts for using REopt's API and Julia package. Please see the [wiki](https://github.com/NatLabRockies/REopt-Analysis-Scripts/wiki) for additional information and setup steps. 

[Open a cloud-hosted Jupyter Notebook to interface with the API using Google Colab](https://colab.research.google.com/github/NatLabRockies/REopt-Analysis-Scripts/blob/HEAD/REopt%20API%20Scripts/google_colab_simple_examples.ipynb)

If you instead wish to develop and use these codebases locally, see instructions [here](https://github.com/NatLabRockies/REopt_API/blob/master/README.md).

**Note:** As of May 2024, the REopt API has decommissioned (end-of-life) v1 and v2 of the API, and the /stable URL is equivalent to v3 which is the only public version of the API. V3 of the API calls the REopt.jl Julia package internally.
