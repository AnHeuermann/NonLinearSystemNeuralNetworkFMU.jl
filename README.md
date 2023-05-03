# NonLinearSystemNeuralNetworkFMU.jl

[![Linux Tests](https://github.com/AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl/actions/workflows/base-tests-linux.yml/badge.svg?branch=main)](https://github.com/AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl/actions/workflows/base-tests-linux.yml)
[![Windows Tests](https://github.com/AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl/actions/workflows/base-tests-windows.yml/badge.svg?branch=main)](https://github.com/AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl/actions/workflows/base-tests-windows.yml)

Generate Neural Networks to replace non-linear systems inside [OpenModelica](https://openmodelica.org/) 2.0 FMUs.

## Working with this repository

This repository uses (private) submodules for the examples.

Clone with `--recursive`:

```bash
git clone git@github.com:AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl.git --recursive
```

To initialize or update your local git repository to use the latest submodules run:

```bash
git submodule update --init
```

## Requirements

  - Julia v1.7.1 or newer.
  - OpenModelica version v1.22.0-dev-43-g33a50c3 or newer.
    - Path has to contain the OpenModelica bin directory `/path/to/OpenModelica/bin/`.
    - For running the tests: Environment variable `OPENMODELICAHOME` set to point to the installation directory of OpenModelica.
  - CMake version 3.21 or newer.
  - ONNX Runtime 1.12 or newer.
    - Environment variable `ORT_DIR` set to point to the installation directory.

## Usage

The package generates an FMU from a modelica file in 3 steps (+ 1 user step):

  1. Find non-linear equation systems to replace.

      * Simulate and profile Modelica model with OpenModelica using
        [OMJulia.jl](https://github.com/OpenModelica/OMJulia.jl).
      * Find slowest equations below given threshold.
      * Find depending variables specifying input and output for every
        non-linear equation system.
      * Find min-max ranges for input variables by analyzing the simulation results.

  2. Generate training data.

      * Generate 2.0 Model Exchange FMU with OpenModelica.
      * Add C interface to evaluate single non-linear equation system without evaluating anything else.
      * Re-compile FMU.
      * Initialize FMU using [FMI.jl](https://github.com/ThummeTo/FMI.jl).
      * Generate training data for each equation system by calling new interface.

  3. Create ONNX (performed by user).

      * Use your favorite environment to create a trained Open Neural Network Exchange ([ONNX](https://onnx.ai/)) model.
        * Use the generated training data to train artificial neural network.

  4. Integrate ONNX into FMU.

      * Replace equations with ONNX evaluation done by [ONNX Runtime](https://onnxruntime.ai/) in generated C code.
      * Re-compile FMU.
        * Environment variable `ORT_DIR` has to be set and point to the ONNX runtime directory (with include/ and lib/ inside).

## Examples

### SimpleLoop

In [examples/SimpleLoop/](examples/SimpleLoop/) and
[examples/SimpleLoop_proximity](examples/SimpleLoop_proximity/) is a simple example
of a non-linear system with two unknowns replaced by a ONNX surrogate. It's less
explanatory but was used to generate plots for a presentation.

All dependencies are managed by [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/),
checkout the [README.md](examples/SimpleLoop/README.md) respectively
[README.md](examples/SimpleLoop_proximity/README.md) (with proximity) for more details.

### IEEE14

There is another example with some larger algebraic systems in
[examples/IEEE14/](./examples/IEEE14/) and
[examples/IEEE14_proximity/](./examples/IEEE14_proximity/) using the
[OpenIPSL](https://github.com/OpenIPSL/OpenIPSL) Modelica library.

All dependencies are managed by [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/),
checkout the [README.md](examples/IEEE14/README.md) respectively
[README.md](examples/IEEE14_proximity/README.md) (with proximity) for more details.

### Scalable Translation Statistics

You'll need access to the PHyMoS GitLab / the ScalableTranslationStatistics Modelica
library to run this example. Check
[examples/ScalableTranslationStatistics/README.md](examples/ScalableTranslationStatistics/README.md)
for more information.

## Debugging

  - It's not possible to debug Julia when OMJulia is used, see
    [OpenModelica/OMJulia.jl#66](https://github.com/OpenModelica/OMJulia.jl/issues/66).
  - Enable debug prints with `ENV["JULIA_DEBUG"] = "all"`.

## Documentation

Currently HTML documentation is not active, but there is a
[PDF](https://github.com/AnHeuermann/NonLinearSystemNeuralNetworkFMU.jl/blob/gh-pages/dev/NonLinearSystemNeuralNetworkFMU.jl.pdf).


## Known Limitations

  - MAT.jl doesn't support the v4 mat files OpenModelica generates, so one
    needs to use CSV result files.

## LICENSE

Copyright (c) 2022 Andreas Heuermann, Philip Hannebohm

-------------------------------------------------------------------------------

NonLinearSystemNeuralNetworkFMU.jl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

NonLinearSystemNeuralNetworkFMU.jl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with NonLinearSystemNeuralNetworkFMU.jl. If not, see <http://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------

NonLinearSystemNeuralNetworkFMU.jl uses header files from the FMI standard, licensed under
BSD 2-Clause (see [FMI-Standard-2.0.3/LICENSE.txt](./FMI-Standard-2.0.3/LICENSE.txt)).

## Acknowledgments

This package was developed as part of the [Proper Hybrid Models for Smarter Vehicles (PHyMoS)](https://phymos.de/en/) project,
supported by the German [Federal Ministry for Economic Affairs and Climate Action](https://www.bmwk.de/Navigation/EN/Home/home.html)
with project number 19|200022G.
