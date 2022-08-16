# NonLinearSystemNeuralNetworkFMU.jl

Generate training data to replace non-linear systems inside
[OpenModelica](https://openmodelica.org/) 2.0 FMUs with trained ONNX models.

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

NonLinearSystemNeuralNetworkFMU.jl uses header files from the FMI standard, licensed under BSD 2-Clause (see [FMI-Standard-2.0.3/LICENSE.txt](./FMI-Standard-2.0.3/LICENSE.txt)).

## Acknowledgments

This package was developed as part of the [Proper Hybrid Models for Smarter Vehicles (PHyMoS)](https://phymos.de/en/) project,
supported by the German [Federal Ministry for Economic Affairs and Climate Action](https://www.bmwk.de/Navigation/EN/Home/home.html)
with project number 19|200022G.
