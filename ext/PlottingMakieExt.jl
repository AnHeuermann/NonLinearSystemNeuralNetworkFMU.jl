#
# Copyright (c) 2023 Andreas Heuermann
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
Provide plot functions if CairoMakie is available
"""
module PlottingMakieExt

import DataFrames
import NonLinearSystemNeuralNetworkFMU

# Provide backwards compatbility (julia >= v1.9 / julia < 1.9 )
isdefined(Base, :get_extension) ? (using CairoMakie) : (using ..CairoMakie)

"""
    plotTrainArea(vars, df_ref; df_surrogate=nothing, df_trainData=nothing, title="", epsilon=0.01, tspan=nothing)

Plot variables `vars` from reference solution `df_ref` as well as a ϵ-tube around it.
If available plot surrogate solution as well as training data into the figure.
Use `tspan` to specify time span to plot.
If df_trainData has column `loss` the color of the data points will be its loss value.
"""
function NonLinearSystemNeuralNetworkFMU.plotTrainArea(vars::Array{String},
                                                       df_ref::DataFrames.DataFrame;
                                                       df_surrogate::Union{DataFrames.DataFrame, Nothing} = nothing,
                                                       df_trainData::Union{DataFrames.DataFrame, Nothing} = nothing,
                                                       title = "",
                                                       epsilon = 0.01,
                                                       tspan::Union{Tuple{Real, Real}, Nothing} = nothing,
                                                       usetricontour::Bool = false)

  aspectRatio = 1.0
  nCols = Integer(ceil(sqrt(length(vars)*aspectRatio)))
  nRows = Integer(ceil(length(vars)/nCols))

  fig = Figure(fontsize = 32,
               resolution = (nRows*800, nCols*600))

  Label(fig[0,:], text=title, fontsize=32, tellwidth=false, tellheight=true)
  grid = GridLayout(nRows, nCols; parent = fig)

  # Filter data frames for tspan
  # This has to be the worst code I have ever written!
  idx_ref = 1:length(df_ref.time)
  local idx_sur
  local idx_data
  if tspan !== nothing
    idx_ref = findall(t -> tspan[1] <= t <= tspan[2], df_ref.time)
    if df_surrogate !== nothing
      idx_sur = findall(t -> tspan[1] <= t <= tspan[2], df_surrogate.time)
    end
    if df_trainData !== nothing
      if in("time", names(df_trainData))
        idx_data = findall(t -> tspan[1] <= t <= tspan[2], df_trainData.time)
      end
    end
  else
    if df_surrogate !== nothing
      idx_sur = 1:length(df_surrogate.time)
    end
    if df_trainData !== nothing && in("time", names(df_trainData))
      idx_data = 1:length(df_trainData.time)
    end
  end

  local l1, l2
  l3 = nothing
  l4 = nothing
  row = 1
  col = 1
  for (i,var) in enumerate(vars)
    axis = Axis(grid[row, col],
                xlabel = "time",
                ylabel = var)

    # Plot reference solution
    l1 = CairoMakie.lines!(axis,
                           df_ref.time[idx_ref], df_ref[!, var][idx_ref],
                           label = "ref")
    # Plot ϵ tube
    l2 = CairoMakie.lines!(axis,
                           df_ref.time[idx_ref], epsilonTube(df_ref[!, var][idx_ref], epsilon),
                           color = :seagreen,
                           linestyle = :dash)

    CairoMakie.lines!(axis,
                      df_ref.time[idx_ref], epsilonTube(df_ref[!, var][idx_ref], -epsilon),
                      color = :seagreen,
                      linestyle = :dash,
                      label = "ϵ: ±$epsilon")

    # Plot surrogate solution
    if df_surrogate !== nothing
      l3 = CairoMakie.lines!(axis,
                             df_surrogate.time[idx_sur], df_surrogate[!, var][idx_sur],
                             color = :orangered1,
                             linestyle = :dashdot,
                             label = "surrogate")
    end

    # Plot training data
    if df_trainData !== nothing
      if in("time", names(df_trainData))
        if in("loss", names(df_trainData))
          if var == "time" || !usetricontour
            CairoMakie.scatter!(axis,
                                df_trainData.time[idx_data], df_trainData[!, var][idx_data],
                                color = df_trainData[!, :loss][idx_data])
          else
            CairoMakie.tricontourf!(axis,
                                    df_trainData.time[idx_data],
                                    df_trainData[!, var][idx_data],
                                    df_trainData[!, :loss][idx_data])
          end
        else
          l4 = CairoMakie.scatter!(axis,
                                   df_trainData.time[idx_data], df_trainData[!, var][idx_data],
                                   color = (:tomato, 0.5))
        end
      else
        if in("loss", names(df_trainData))
          colorrange = (minimum(df_trainData.loss), maximum(df_trainData.loss))
          for (i,data) in enumerate(df_trainData[!, var])
            CairoMakie.lines!(axis,
                              df_ref.time[idx_ref[1:end-1:end]], [data, data],
                              color = [df_trainData.loss[i], df_trainData.loss[i]],
                              colormap = :viridis,
                              colorrange = colorrange)
          end
        else
          for data in df_trainData[!, var]
            l4 = CairoMakie.lines!(axis,
                                   df_ref.time[idx_ref[1:end-1:end]], [data, data],
                                   color = (:tomato, 0.5))
          end
        end
      end
    end

    if i%nCols == 0
      row += 1
      col = 1
    else
      col += 1
    end
  end

  #colsize!.(grid, 1, Relative(1/nRows))
  fig[1,1] = grid

  labels = Vector{Any}([l1, l2])
  label_names = ["reference", "ϵ: ±$epsilon"]
  if df_surrogate !== nothing
    push!(labels, l3)
    push!(label_names, "surrogate")
  end
  if df_trainData !== nothing
    if !in("loss", names(df_trainData))
      push!(labels, l4)
      push!(label_names, "data")
    end
  end

  Legend(fig[2, 1],
         labels,
         label_names,
         orientation = :horizontal, tellwidth = false, tellheight = true)

  if df_trainData !== nothing && in("loss", names(df_trainData))
    local limits
    if in("time", names(df_trainData))
      limits = (minimum(df_trainData.loss[idx_data]), maximum(df_trainData.loss[idx_data]))
    else
      limits = (minimum(df_trainData.loss), maximum(df_trainData.loss))
    end
    Colorbar(fig[1, 2], limits = limits,
             label = "data loss",
             flipaxis = true, tellwidth = false, tellheight = false)
    colsize!(fig.layout, 1, Aspect(1, 1.25))
  end

  resize_to_layout!(fig)
  return fig
end

function epsilonTube(values::Vector{Float64}, ϵ=0.1)
  nominal = 0.5* (minimum(abs.(values)) + maximum(abs.(values)))
  return values .+ ϵ*nominal
end

end # module
