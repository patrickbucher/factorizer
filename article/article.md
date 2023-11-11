---
title: 'Prime Factorization'
subtitle: 'Case Study in Elixir Concurrency (Coming From Go)'
author: 'Patrick Bucher'
---

The concurrency model used in Elixir (and Erlang), often referred to as the
_Actor Model_, is quite similar to the model used in Go, which is called
_Communicating Sequential Processes_. There are many things in common, indeed:

- Both Elixir's (or Erlang's) _processes_ and Go's _goroutines_ are
  light-weight. It's practical to have hundreds or even thousands of them, which
  are mapped to operating system threads in a _n:m_ manner (_n_ OS threads
  running _m_ processes/goroutines).
- Both models facilitate message passing between concurrent units of executions
  (processes/goroutines).
- Both languages offer language constructs to deal with incoming messages:
  `receive` in Elixir, `select/case` and the arrow operator `<-` in Go.

However, there are a few important differences, which may make a programmer
coming over from Go (or a language solely using a shared-memory and thread-based
model like Java, for that matter) to Elixir struggle:

- In Elixir, processes do not share memory, whereas Go offers facilities for
  both concurrency styles—message passing and shared memory.
- Elixir's `spawn/1` starts a new process and returns a process identifier
  (PID), whereas Go's `go` creates a new goroutine and returns nothing.
- Knowing a process' PID is sufficient to send it a message in Elixir, whereas
  in Go channels known to both goroutines are required for communication between
  them.
- As a consequence, a goroutine can wait for a message from a specific channel
  (possibly only known to another specific goroutine), whereas in Elixir a
  process can just wait for any message coming from any process.
- Implementing a message loop in Elixir requires (tail) recursion, whereas Go
  uses (infinite) loops.
- Being a dynamically typed language, incoming messages are matched against a
  pattern in Elixir, whereas Go uses typed channels, which deliver messages of
  the same type and shape.

Having worked with Go's model, the author's goal is to become acquainted wich
Elixir's model by solving the problem stated below.

# Problem

Natural numbers can be expressed as a product of prime numbers. For example, 12
can be expressed as the product of 2, 2, and 3, whereas 13, which is a prime
number itself, can be expressed as a product of 13. A few examples:

| Number |       Prime Factors |
|-------:|--------------------:|
|     24 |          2, 2, 2, 3 |
|     30 |             2, 3, 5 |
|    128 | 2, 2, 2, 2, 2, 2, 2 |
|    140 |          2, 2, 5, 7 |

The prime factors of a number $x$ can be found as follows:

1. All the prime numbers $p$ in the range $2 \leq p \leq \sqrt{x}$ have to be
   found, which can be achieved using brute force or an algorithm such as the
   [Sieve of Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes).
   (Only finding the prime numbers $\leq \sqrt{x}$ is a heuristic, because no
   natural number results from the division of $x$ by a prime number $p >
   \sqrt{x}$.)
2. The sequence of prime numbers found, which must be ordered ascendingly, is
   processed as follows:
    1. The number $x$ is divided by the first prime number $p_i$.
    2. If this division yields a natural number, $p_i$ is added to the sequence
       of prime factors, and $x$ becomes the result of that division. This step
       is repeated, until the division of $p_i$ yields a fraction.


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
