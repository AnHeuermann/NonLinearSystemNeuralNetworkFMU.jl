#
# Copyright (c) 2022-2023 Andreas Heuermann
#
# This file is part of NonLinearSystemNeuralNetworkFMU.jl.
#
# NonLinearSystemNeuralNetworkFMU.jl is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# NonLinearSystemNeuralNetworkFMU.jl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with NonLinearSystemNeuralNetworkFMU.jl. If not, see <http://www.gnu.org/licenses/>.
#

"""
    runOutput(cmd)

Run comand `cmd` and return output from stdout as String.
If an error is encountered print stderr and rethrow error.
"""
function runOutput(cmd::Cmd)::String
  # Get version string
  local stdout
  # IOBuffer breaks on Windows, see https://github.com/JuliaLang/julia/issues/39311
  # Base.BufferStream are undocumented, but should be non-OS streams,
  # so they shouldn't break everything. Otherwise use text files.
  out = Base.BufferStream()
  err = Base.BufferStream()
  try
    run(pipeline(cmd; stdout=out, stderr=err))
    stdout = read(out, String)
  catch e
    println(read(err, String))
    rethrow(e)
  finally
    close(out)
    close(err)
  end

  return stdout
end

"""
    testCMakeVersion(;minimumVersion = "3.21")

Test if CMake can be found in PATH and minimum version is satisfied.
Returns used version or throw an error if minimum version is not satisfied.
"""
function testCMakeVersion(;minimumVersion = "3.21")
  # Find cmake
  try
    if Sys.iswindows()
      run(pipeline(`where cmake.exe`; stdout=devnull))
    else
      run(pipeline(`which cmake`; stdout=devnull))
    end
  catch
    throw(ProgramNotFoundError("cmake", [ENV["PATH"]]))
  end

  # Get version string
  version = runOutput(`cmake --version`)
  version = split(strip(version))[1:3]
  @assert version[1] == "cmake"
  @assert version[2] == "version"
  version = version[3]

  if version < minimumVersion
    throw(MinimumVersionError("CMake", minimumVersion, version))
  end

  return version
end


"""
    getomc([omc])

Try to find omc executable.
Seach order: Given string, `PATH` and then in `OPENMODELICAHOME`.
Throws error if omc isn't found.
"""
function getomc(omc::String="")
  searchedLocations = []

  # Try provided string
  if !isempty(strip(omc))
    testOmcVersion(omc)
    return omc
  end
  push!(searchedLocations, omc)

  # Try PATH
  try
    if Sys.iswindows()
      omc = string(strip(read(`where omc.exe`, String)))
    else
      omc = string(strip(read(`which omc`, String)))
    end
    testOmcVersion(omc)
    return omc
  catch
  end
  push!(searchedLocations, ENV["PATH"])

  # Try OPENMODELICAHOME
  if haskey(ENV, "OPENMODELICAHOME")
    if Sys.iswindows()
      omc = abspath(joinpath(ENV["OPENMODELICAHOME"], "bin", "omc.exe"))
    else
      omc = abspath(joinpath(ENV["OPENMODELICAHOME"], "bin", "omc"))
    end
    push!(searchedLocations, ENV["OPENMODELICAHOME"])
    if isfile(omc)
      testOmcVersion(omc)
      return omc
    end
  end

  throw(ProgramNotFoundError("omc", searchedLocations))
end

"""
    testOmcVersion(omc;  minimumVersion = "v1.20.0-dev-342")

Test if OMC version is higher than minimum version.
Throw error if omc can't be found or minimum version is not satisfied.
"""
function testOmcVersion(omc; minimumVersion = "v1.20.0-dev-342")
  # Check if path points to a file
  if !isfile(omc)
    throw(ProgramNotFoundError("omc", [ENV["PATH"]]))
  end
  @debug "Using omc: $omc"

  # Get version string
  version = runOutput(`$omc --version`)
  version = strip(replace(version, "OpenModelica "=>""))

  def_min = "9999"
  main_ver_min = minimumVersion
  loc = findStrWError("dev", minimumVersion)
  if findfirst("~", minimumVersion) !== nothing
    (main_ver_min, _) = split(minimumVersion, "~")
  else
    (main_ver_min, def_min) = split(minimumVersion, "-")[1:2:3]
  end
  if startswith(main_ver_min, "v")
    main_ver_min = main_ver_min[2:end]
  end

  def_omc = "0"
  main_ver_omc = version
  if occursin("dev", version)
    loc = findStrWError("dev", version)
    if findfirst("~", version) !== nothing
      (main_ver_omc, _) = split(version, "~")
    else
      (main_ver_omc, def_omc) = split(version, "-")[1:2:3]
    end
    if startswith(main_ver_omc, "v")
      main_ver_omc = main_ver_omc[2:end]
    end
  end

  if main_ver_omc < main_ver_min
    @show main_ver_omc, main_ver_min
    throw(MinimumVersionError("omc", minimumVersion, version))
  elseif main_ver_omc == main_ver_min && def_omc < def_min
    @show def_min, def_omc
    throw(MinimumVersionError("omc", minimumVersion, version))
  end

  return true
end


"""
    findStrWError(searchStr, str)

Like findfirst for strings, but throws error if no result was found.

See also `findfirst`.
"""
function findStrWError(searchStr::AbstractString, str::AbstractString)
  result = findfirst(searchStr, str)
  if result === nothing
      throw(StringNotFoundError(searchStr))
  else
    return result
  end
end


"""
    findStrWError(searchStr, str, index)

Like findnext for strings, but throws error if no result was found.

See also `findnext`.
"""
function findStrWError(searchStr::AbstractString, str::AbstractString, index::Integer)
  result = findnext(searchStr, str, index)
  if result === nothing
      throw(StringNotFoundError(searchStr))
  else
    return result
  end
end
