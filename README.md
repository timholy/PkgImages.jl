# PkgImages

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://timholy.github.io/PkgImages.jl/dev/)
[![Build Status](https://github.com/timholy/PkgImages.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/timholy/PkgImages.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/timholy/PkgImages.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/timholy/PkgImages.jl)

This "package" is a prototype for various operations needed for a next-generation package cache in Julia,
targeted to be merged in the Julia 1.9 and/or 1.10 timeframe. Many of these operations are currently
performed in Julia's `dump.c` (and perhaps soon, `staticdata.c`); at present it seems possible that at
least a subset of this could be written in Julia and move into `Core`. If that isn't viable, then
at least this package may be useful for planning implementations.

Features that are implemented or in-progress include:

- handling of backedges and their validation in the user's environment
