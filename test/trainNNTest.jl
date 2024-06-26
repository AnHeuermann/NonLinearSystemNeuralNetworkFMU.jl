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

using Test

import BSON
import CSV
import DataFrames
import Flux
import InvertedIndices
import ONNXNaiveNASflux
import StatsBase

"""
    readData(filename, nInputs; ratio=0.8)

# Arguments
  - `filename::String`: Path of CSV file with training data.
  - `nInputs::Integer`: Number of input varaibles for model.

# Keywords
  - `ratio=0.8`: Ratio between training and testing data points.
                 Defaults to 80% training and 20% testing.
  - `shuffle::Bool=true`: Shufle training and testing from data.
"""
function readData(filename::String, nInputs::Integer; ratio=0.8, shuffle::Bool=true)
  df = DataFrames.select(CSV.read(filename, DataFrames.DataFrame; ntasks=1), InvertedIndices.Not([:Trace]))
  m = Matrix{Float32}(df)
  n = length(m[:,1])
  num_train = Integer(round(n*ratio))
  if shuffle
    trainIters = StatsBase.sample(1:n, num_train, replace = false)
  else
    trainIters = 1:num_train
  end
  testIters = setdiff(1:n, trainIters)

  train_in  = [m[i, 1:nInputs]     for i in trainIters]
  train_out = [m[i, nInputs+1:end] for i in trainIters]
  test_in   = [m[i, 1:nInputs]     for i in testIters]
  test_out  = [m[i, nInputs+1:end] for i in testIters]
  return train_in, train_out, test_in, test_out
end

"""
Filter data for `x = r*s-y <= y` to get uniqe data points.
"""
function isRight(s,r,y)
  x = r*s-y
  return x > y
end

"""
Filter training data to only contain unambiguous data points
by using only the bottom right intersection points.
"""
function filterData(data_in, data_out)
  s = [x[2] for x in data_in];
  r = [x[2] for x in data_in];
  y = [x[1] for x in data_out];

  keep = findall(i->(i==true), isRight.(s, r, y))

  filtered_data_in = data_in[keep]
  filtered_data_out = data_out[keep]
  return (filtered_data_in, filtered_data_out)
end

"""
    trainSurrogate!(model, dataloader, test_in, test_out, savename; losstol=1e-6, nepochs=100, eta=1e-3)

Train surrogate on data from `dataloader`.
Stop when `losstol` is reached. Saves model with minimal loss.

# Arguments
  - `model`: Flux model to train.
  - `dataloader::Flux.DataLoader`: DataLoader with trainig data.
  - `train_in`: Single btatch of train input data.
  - `train_out`: Single btatch of train output data.
  - `savename::String`: Path to location where trained model is saved to.

# Keywords
  - `losstol::Real=1e-6`: Loss to reach for model.
  - `nepochs=100`: Number of epochs to train.
  - `eta=1e-3`: η parameter for Flux.ADAM.
"""
function trainSurrogate!(model, dataloader::Flux.DataLoader, train_in, train_out, savename::String; losstol::Real=1e-6, nepochs=100, eta=1e-3)
  # Create directory for bson file
  mkpath(dirname(savename))

  # Compute initial loss
  ps = Flux.params(model)
  opt = Flux.Adam(eta)
  loss(x,y) = Flux.mse(model(x),y)
  disp_loss() = sum(loss.(train_in,train_out))/length(train_in)
  callback = Flux.throttle(disp_loss, 5)
  minL = disp_loss()
  @info "Initial loss: $(minL)"
  if minL < losstol
    BSON.@save savename model
    return
  end

  @info "Start training"
  epoch = 0
  try
    while epoch < nepochs
      epoch += 1
      for (ti,to) in dataloader
        Flux.train!(loss, ps, zip(ti,to), opt, cb=callback)
      end
      l = disp_loss()
      @info "Epoch $(epoch): Train loss=$(l)"
      if l < minL
        BSON.@save savename model
        minL = l
        if minL < losstol
          @info "Success"
          break
        end
      end
    end
  catch e
    if isa(e, InterruptException)
      @info "Aborted"
    else
      rethrow(e)
    end
  end

  @info "Best loss = $(minL)\n\tAfter $(epoch) epochs"
end

"""
    getNN()

Load NN model from nn/simpleLoop_eq14.bson.
"""
function getNN()
  outname = abspath(joinpath(@__DIR__, "nn", "simpleLoop_eq14.bson"))
  dict = BSON.load(outname, @__MODULE__)  # SafeTestsets puts everything into a module
  return dict[first(keys(dict))]
end

"""
    testLoss(test_in, test_out)

Compute and display loss for test data.
"""
function testLoss(test_in, test_out)
  model = getNN()
  loss(x,y) = Flux.mse(model(x),y)
  disp_loss() = sum(loss.(test_in,test_out))/length(test_in)
  @info "Test loss=$(disp_loss())"
end

function runTrainNNTest()
  fileName = abspath(joinpath(@__DIR__, "data", "simpleLoop_eq14.csv"))
  nInputs = 2
  nOutputs = 1
  outname = abspath(joinpath(@__DIR__, "nn", "simpleLoop_eq14.bson"))
  rm(outname, force = true)

  (train_in, train_out, test_in, test_out) = readData(fileName, nInputs)
  (train_in, train_out) = filterData(train_in, train_out)
  (test_in, test_out) = filterData(test_in, test_out)

  dataloader = Flux.DataLoader((train_in, train_out), batchsize=64, shuffle=true)

  model = Flux.Chain(Flux.Dense(nInputs, 5, tanh),
                    Flux.Dense(5, 5, tanh),
                    Flux.Dense(5, nOutputs))

  trainSurrogate!(model, dataloader, train_in, train_out, outname; nepochs=100)
  @test isfile(outname)

  testLoss(test_in, test_out)

  onnxModel =  abspath(joinpath(@__DIR__, "nn", "simpleLoop_eq14.onnx"))
  rm(onnxModel, force = true)
  ONNXNaiveNASflux.save(onnxModel, model, (nInputs,1))
  @info "Generated $onnxModel"

  @test isfile(onnxModel)
end

runTrainNNTest()
