# Function to safely extract values from JSON with default value if key is missing
function safe_get(data::Union{Dict{String, Any}, Vector{Dict}}, keys::Union{Vector{String}, Vector{Any}}, default=0.0)
    try
        for k in keys
            data = data[k]
        end
        #check if the result is empty 
        if data == []
            return [0.0]
        end
        return data
    catch e
        if e isa KeyError
            return default
        else
            rethrow(e)
        end
    end
end

function safe_get2(data::Any, keys::Vector{String}, default=0.0)
    try
        for k in keys
            if data isa Dict{String, Any}
                data = data[k]
            else
                return default  # Return default if data is not a dictionary
            end
        end
        # Handle cases where the result is 0 or an empty list
        if data == 0 || data == []
            return default
        end
        return data
    catch e
        if e isa KeyError
            return default  # Return default if the key is missing
        else
            rethrow(e)  # Re-throw other exceptions
        end
    end
end
