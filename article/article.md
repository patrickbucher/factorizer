---
title: 'Exploring Concurrency in Elixir'
subtitle: 'Using Prime Factorization'
author: 'Patrick Bucher'
---

# Problem

TODO: prime factorization, finding prime numbers (CPU-bound)

# Building Blocks

TODO: setup using mix, prime sieve (of Eratosthenes), factorization, stop watch,
unit tests

# Basic Implementation

TODO: Factorizer, without Concurrency, `factorizer.ex` is `Factorizer`, etc.

# Basic Parallel Implementation

TODO: using primitives

# Client/Server Implementation

TODO: splitting concurrency boiler-plate from program logic

# Callback Implementation

TODO: introducing state, as well as cast/call message patterns

# GenServer Implementation

TODO: use GenServer instead of hand-made callback structure

# Timings

TODO: overview table

|               | 1 | 10 | 100 | 1000 |
|---------------|--:|---:|----:|-----:|
| Basic         |   |    |     |      |
| Parallel      |   |    |     |      |
| Client/Server |   |    |     |      |
| GenServer     |   |    |     |      |

# Conclusion

TODO: some lofty thoughts

# Sources

Saša Jurić: _Elixir in Action_ (Second Edition), Manning 2019, ISBN-13: 9781617295027
