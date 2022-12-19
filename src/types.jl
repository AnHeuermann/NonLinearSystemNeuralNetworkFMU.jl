#
# Copyright (c) 2022 Andreas Heuermann
#
# This file is part of NonLinearSystemNeuralNetworkFMU.jl.
#
# NonLinearSystemNeuralNetworkFMU.jl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# NonLinearSystemNeuralNetworkFMU.jl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NonLinearSystemNeuralNetworkFMU.jl. If not, see <http://www.gnu.org/licenses/>.
#

"""
    EqInfo <: Any

Equation info struct.

$(DocStringExtensions.TYPEDFIELDS)
"""
struct EqInfo
  "Unique equation id"
  id::Int64
  "Number of calls during simulation"
  ncall::Int64
  "Total time [s] spend on evaluating this equation."
  time::Float64
  "Maximum time [s] needed for single evaluation of equation."
  maxTime::Float64
  "Fraction of total simulation time spend on evaluating this equation."
  fraction::Float64
  EqInfo(id, ncall, time, maxTime, fraction) = new(id, ncall, time, maxTime, fraction)
  EqInfo(;id, ncall, time, maxTime, fraction) = new(id, ncall, time, maxTime, fraction)
end

function Base.show(io::IO, ::MIME"text/plain", eqInfo::EqInfo)
  Printf.@printf(io, "EqInfo(id=%s, ", eqInfo.id)
  Printf.@printf(io, "ncall=%s, ", eqInfo.ncall)
  Printf.@printf(io, "time=%s, ", eqInfo.time)
  Printf.@printf(io, "maxTime=%s, ", eqInfo.maxTime)
  Printf.@printf(io, "fraction=%s)", eqInfo.fraction)
end

"""
    ProfilingInfo <: Any

Profiling information for single non-linear equation.

$(DocStringExtensions.TYPEDFIELDS)
"""
struct ProfilingInfo
  "Non-linear equation"
  eqInfo::EqInfo
  "Iteration (output) variables of non-linear system"
  iterationVariables::Array{String}
  "Inner (torn) equations of non-linear system."
  innerEquations::Array{Int64}
  "Used (input) variables of non-linear system. "
  usingVars::Array{String}
end

function Base.show(io::IO, ::MIME"text/plain", profilingInfo::ProfilingInfo)
  Printf.@printf(io, "ProfilingInfo(%s, ", profilingInfo.eqInfo)
  Printf.@printf(io, "iterationVariables: %s, ", profilingInfo.iterationVariables)
  Printf.@printf(io, "innerEquations: %s, ", profilingInfo.innerEquations)
  Printf.@printf(io, "usingVars: %s)", profilingInfo.usingVars)
end

"""
Program not found in PATH error.
"""
struct ProgramNotFoundError <: Exception
  program::String
  locations::Union{Nothing, Array{String}}
  ProgramNotFoundError(program) = new(program, nothing)
end
function Base.showerror(io::IO, e::ProgramNotFoundError)
  println(io, e.program, " not found")
  if e.locations !== nothing
    for loc in e.locations
      println(io, "Searched in " * loc)
    end
  end
end

"""
Minimum version not sattisfied error.
"""
struct MinimumVersionError <: Exception
  program::String
  minimumVersion::String
  currentVersion::String
end
function Base.showerror(io::IO, e::MinimumVersionError)
  println(io, e.program, " minimum version requierment not satisfied.")
  println(io, "Minimum version needed is $(e.minimumVersion).")
  print(io, "Using version $(e.currentVersion).")
end

"""
String not found in searched string error.
"""
struct StringNotFoundError <: Exception
  searchString::String
end
function Base.showerror(io::IO, e::StringNotFoundError)
  print(io, "Could not find string \"", e.searchString, " \"")
end

"""
OpenModelica error with log file.
"""
struct OpenModelicaError <: Exception
  msg::String
  logFile::String
end
function Base.showerror(io::IO, e::OpenModelicaError)
  println(io, e.msg)
  println(io, "Log file: ", e.logFile)
  if isfile(e.logFile)
    print(io, read(e.logFile, String))
  end
end

"""
    getUsingVars(bsonFile, eqNumber)

# Arguments
  - `bsonFile::String`:  name of the binary JSON file
  - `eqNumber::Int`:  number of the slowest equation
# Return:
  - array of the using variables and length of the array
"""
function getUsingVars(bsonFile::String, eqNumber::Int)
  # load BSON file
  dict = BSON.load(bsonFile)
  profilingInfo = Array{ProfilingInfo}(dict[first(keys(dict))])
  # Find array element i with eqNumber
  for i = 1:length(profilingInfo)
    if profilingInfo[i].eqInfo.id == eqNumber
      return profilingInfo[i].usingVars , length([profilingInfo[i].usingVars][i])
    end
  end
end

"""
    getIterationVariables(bsonFile, eqNumber)

# Arguments
  - `bsonFile::String`:  name of the binary JSON file
  - `eqNumber::Int`:  number of the slowest equation
# Return:
  - array of the iteration variables and length of the array
"""
function getIterationVariables(bsonFile::String, eqNumber::Int)
  # load BSON file
  dict = BSON.load(bsonFile)
  profilingInfo = Array{ProfilingInfo}(dict[first(keys(dict))])
  # Find array element i with eqNumber
  for i = 1:length(profilingInfo)
    if profilingInfo[i].eqInfo.id == eqNumber
      return [profilingInfo[i].iterationVariables] , length([profilingInfo[i].iterationVariables][i])
    end
  end
end

"""
    getInnerEquations(bsonFile, eqNumber)

# Arguments
  - `bsonFile::String`:  name of the binary JSON file
  - `eqNumber::Int`:  number of the slowest equation
# Return:
  - array of the inner equations and length of the array
"""
function getInnerEquations(bsonFile::String, eqNumber::Int)
  # load BSON file
  dict = BSON.load(bsonFile)
  profilingInfo = Array{ProfilingInfo}(dict[first(keys(dict))])
  # Find array element i with eqNumber
  for i = 1:length(profilingInfo)
    if profilingInfo[i].eqInfo.id == eqNumber
      return [profilingInfo[i].innerEquations] , length([profilingInfo[i].innerEquations][i])
    end
  end
end
