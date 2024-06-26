using DrWatson
@quickactivate "IEEE14"

using NonLinearSystemNeuralNetworkFMU
using CUDA

if CUDA.functional()
  ENV["XLA_FLAGS"] = "--xla_gpu_cuda_data_dir=/usr/local/cuda-12.1"
end

N = 1000

bsonFile = datadir("sims", "IEEE_14_Buses_$(N)", "profilingInfo.bson")
profilingInfo = NonLinearSystemNeuralNetworkFMU.getProfilingInfo(bsonFile)

eqName = "eq_$(profilingInfo[1].eqInfo.id)"
nInputs = length(profilingInfo[1].usingVars)
nOutputs = length(profilingInfo[1].iterationVariables)
csvFile = datadir("sims", "IEEE_14_Buses_$(N)", "data", "$eqName.csv")

workdir = datadir("sims", "IEEE_14_Buses_$(N)", "temp-train-tf")
rm(workdir, force=true, recursive=true)
mkpath(workdir)

cmd = `python $(srcdir("train.py")) $(eqName) $(workdir) $(nInputs) $(nOutputs) $(csvFile)`

run(Cmd(cmd, dir = workdir))
