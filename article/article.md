---
title: 'Concurrent Prime Factorization'
subtitle: 'Case Study in Elixir (Coming From Go)'
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
- Both languages offer language constructs for dealing with incoming messages:
  `receive` in Elixir, `select/case` and the arrow operator `<-` in Go.

However, there are a few important differences, which may make a programmer
coming over from Go (or a language solely using a shared-memory and thread-based
model like Java, for that matter) to Elixir struggle:

- In Elixir, processes do not share memory, whereas Go offers facilities for
  both concurrency styles—message passing and shared memory.
- Elixir's `spawn/1` function starts a new process and returns a process
  identifier (PID), whereas Go's `go` keyword creates and starts a new goroutine
  and returns nothing.
- Knowing a process' PID is sufficient to send it a message in Elixir, whereas
  in Go channels known to both goroutines are required for communication between
  them.
- As a consequence, a goroutine can wait for a message from a specific channel
  (possibly only known to another specific goroutine), whereas in Elixir a
  process can just wait for any incoming message being sent from any process.
- Implementing a message loop in Elixir requires (tail) recursion, whereas Go
  uses (infinite) loops.
- Being a dynamically typed language, incoming messages are matched against
  patterns in Elixir, whereas Go uses typed channels, which deliver messages of
  the same type and shape.

Having worked with Go's model, the author's goal is to become acquainted wich
Elixir's model by solving the problem stated below.

# Problem

Natural numbers can be expressed as a product of prime numbers. For example, 12
is the product of 2, 2, and 3, whereas 13, which is a prime number itself, is
the product of 13 (and the neutral element 1, which is not a prime number). A
few examples:

| Number | Prime Factors |                                 Check |
|-------:|--------------:|--------------------------------------:|
|     12 |       2, 2, 3 |            $2 \times 2 \times 3 = 12$ |
|     13 |            13 |                             $13 = 13$ |
|     24 |    2, 2, 2, 3 |   $2 \times 2 \times 2 \times 3 = 24$ |
|     30 |       2, 3, 5 |            $2 \times 3 \times 5 = 30$ |
|    140 |    2, 2, 5, 7 |  $2 \times 2 \times 5 \times 7 = 140$ |
|    580 |   2, 2, 5, 29 | $2 \times 2 \times 5 \times 29 = 580$ |

Factorizing a number into its prime factors is useful for arithmetics (finding
the greatest common divisor of two numbers, canceling fractions) or for
cryptoanalysis (e.g. cracking RSA key-pairs).

## Algorithm

The prime factors of a number $x$ can be found as follows using the _Trial
Division Method_, which is rather inefficient, but easy to understand:

1. The prime numbers $p$ in the range $2 \leq p \leq \sqrt{x}$ have to be found,
   which can be achieved using brute force or an algorithm such as the [Sieve of
   Eratosthenes](https://en.wikipedia.org/wiki/Sieve_of_Eratosthenes).
   - Only finding the prime numbers $p \leq \sqrt{x}$ is sufficient: If $n$ is
     divisible by $p$, then $n = p \times q$. Checking divisibility of $n$ by
     $q >= p$ will only give results that would have been found earlier in the
     process. If $p = q$, then $n = p^2$ and $\sqrt{n} = p$, so $\sqrt{n}$ is
     the upper limit of primes to be tested for divisibility.
2. The sequence of prime numbers found of length $n$, which must be ordered
   ascendingly, is processed from $p_0$ to $p_{n-1}$ with index $i$:
    1. The number $x$ is divided by the prime number $p_i$, yielding a rest $r$
       ($r=x \div p_i$).
    2. If $r$ is a natural number, $p_i$ is added to the sequence of prime
       factors. This step is repeated with $x=r$ as long as the remainder $r$
       is a natural number.
    3. If the remainder $r$ is not a natural number, the above step is retried
       with the next prime number $p_{i+1}$.
    4. The process finishes when the remainder $r$ becomes $1$. The sequence of
       found prime factors is returned as the result.

This computation, especially the first step (finding the prime numbers), is
computationally expensive. If the task of finding prime factors is extended to
multiple numbers to be factorized, the work can be parallelized, because the
individual factorizations can be performed independently. The prime
factorization of a sequence of natural numbers is therefore a problem well
suited for a case study in CPU-bound concurrency.

# Building Blocks

First, the algorithm described in the section above shall be implemented in a
new Elixir project, which is created using the `mix` tool (using Elixir
v1.15.7):

    $ mix new factorizer

This creates a scaffold in the folder `factorizer/` with source code files in
the `lib/` sub-folder, and test cases in `test/`. A module called `Factorizer`
is already provided in `lib/factorizer.ex`, which shall be implemented right
after the next step.

## Prime Sieve (of Eratosthenes)

Before factorization can be dealt with, prime numbers have to be found. The
module `PrimeSieve`  implemented in `lib/prime_sieve.ex` uses a lazy
[Stream](https://hexdocs.pm/elixir/1.15.7/Stream.html) to implement the Sieve of
Eratosthenes.

The `Stream.unfold/2` function requires two arguments: An initial accumulator of
already found prime numbers, which initially is the empty list `[]`, and a
function expecting the accumulator and returning a two-element tuple: the first
element being the next prime number found, and the second element being the new
accumulator—the list of prime numbers found, including the one just found as the
list's head. This function is called later again with the updated accumulator to
find the next prime number:

```elixir
Stream.unfold([], fn
  [] -> {2, [2]}
  [h | t] -> next(h + 1, [h | t])
end)
```

The anonymous function used for the computation of the next element has two
clauses: The first matching an empty list returns 2 as the first prime number
with a new accumulator of `[2]` as the prime numbers found so far; the second
matches a non-empty list, for which the next prime number is to be found based
on the list's head. (Like lists, streams are built up by adding elements to its
head).

The `next/2` function is implemented as follows:

```elixir
defp next(n, primes) do
  if Enum.any?(primes, fn p -> rem(n, p) == 0 end) do
    next(n + 1, primes)
  else
    {n, [n | primes]}
  end
end
```

The first parameter `n` is the number to be tried for primality using the prime
numbers already found given as the second parameter `primes`. Whether or not `n`
is a prime number is decided using the `Enum.any/2` higher-order function, which
is stated in the negative: If `n` is divisible without a remainder by _any_
smaller prime number, it is _not_ a prime number. The successor of `n` shall be
retried in this case, without extending the accumulator, since no new prime
number was found. If none of the prime numbers divides `n` without a remainder,
`n` is a prime number, which is both returned as the next element of the stream,
and as the head of the updated accumulator.

Why is a number $n$ only checked for divisability by _prime_ numbers $p < n$ and
not by _all_ numbers $m < n$? Because if $n$ is not divisible by $m$, it won't
be divisible by $m^2$. E.g. if $13$ is not divisible by $2$, how could it be
divisible by $4=2^2$, which is the same as being divisible by $2$ _twice_?

A further optimisation would be to filter `primes` to $p <= \frac{n}{2}$,
because no $p > \frac{n}{2}$ could divide $n$ such that the result would be a
natural number (e.g. $13 \div 7 < 1$). This is left as an exercise to the
reader. (Note that `primes` is built up in _descending_ order.)

For the public API of the `PrimeSieve` module, the following functions are
offered:

```elixir
def first(n) do
  stream() |> Enum.take(n)
end

def up_to(n) do
  stream() |> Enum.take_while(&(&1 <= n))
end

def stream() do
  Stream.unfold([], fn
    [] -> {2, [2]}
    [h | t] -> next(h + 1, [h | t])
  end)
end
```

1. `first/1`: Returning a sequence of the first `n` prime numbers.
2. `up_to/1`: Returning a sequence of the first prime numbers up to and
   including `n`.
3. `stream/0`: Returning the stream to be consumed directly by the caller.

See `lib/prime_sieve.ex` for the full implementation of the `PrimeSieve` module.

## Prime Factorization

Prime factorization is implemented in the `PrimeFactors` module
(`lib/prime_factors.ex`). The public API consists solely of the function
`factorize/1`, which accepts a number `n` to be factorized, and returns a list
of prime factors:

```elixir
def factorize(n) do
  primes = PrimeSieve.up_to(:math.sqrt(n))
  next(n, primes, [])
end
```

First, the prime numbers up to and including $\sqrt{n}$ are found using
`PrimeSieve.up_to/1`. Second, the prime factors are determined using those prime
numbers and the `next/3` function, which expects three parameters: the number to
be factorized, the prime numbers to be tested divisibility for, and an
accumulator to collect the found prime factors.

There are two base cases to be covered:

1. The number to be factorized has been divided down to 1, in which case the
   accumulator is the result of the factorization. (1 is the neutral element of
   the division and not a prime number, hence not part of the result.)
2. The prime numbers to be tried have been exhausted, in which case the
   remainder must be a prime number itself and is added as the final prime
   factor to the result.

Those base cases are handled by the following function clauses:

```elixir
defp next(1, [], acc) do
  Enum.reverse(acc)
end

defp next(n, [], acc) do
  Enum.reverse([n | acc])
end
```

Since the accumulator is built up from the head, it is reversed for the final
result so that the smallest factor is at the beginning of the list and the
biggest factor at the end of it.

Trial division is implemented as the general case of the `next/3` function:

```elixir
defp next(n, [h | t], acc) do
  if rem(n, h) == 0 do
    next(div(n, h), [h | t], [h | acc])
  else
    next(n, t, acc)
  end
end
```

If the given number `n` is divisible by the first prime number `h`, then `h` is
a prime factor. The following arguments are passed to the recursive call:

1. The remainder of dividng `n` by `h`.
2. The same prime numbers that have been received by the current call.
3. The accumulator with `h` as another prime factor at its head.

Otherwise, `h` is not a prime factor, in which case the original number, the
remaining prime numbers, and the given accumulator are passed to the recursive
call.

In the first case (success), the first argument `n` is reduced towards 1; in the
second case (failure), the second argument (prime numbers) is reduced towards
the empty list. So both cases are reduced to one of the two base cases explained
above.

The `PrimeFactors.factorize/1` function can be used as follows in `iex`:

```elixir
> PrimeFactors.factorize(1050)
[2, 3, 5, 5, 7]
```

The result can be checked by multiplying the found prime factors:

```elixir
> Enum.reduce([2, 3, 5, 5, 7], &*/2)
1050
```

## Stopwatch

In order to measure the running times of prime number factorization (or some
other arbitrary code, for that matter), the `Stopwatch` module
(`lib/stopwatch.ex`) is provided:

```elixir
defmodule Stopwatch do
  def timed(fun) do
    {time, value} = :timer.tc(fun)
    seconds = time / 1.0e6
    IO.puts("#{seconds}s")
    value
  end
end
```

The function `timed/1` expects a function, which is run by the Erlang function
`:timer.tc/1`. This function returns both a time (in milliseconds) and the
result of the given function. The measured time is converted to seconds and
printed to the console; the value is returned.

The `Stopwatch.timed/1` function can be used as follows:

```elixir
> Stopwatch.timed(fn -> PrimeFactors.factorize(1_000_000_000) end)
0.415278s
[2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5]
```

This allows for some rough comparisons between implementations, which is enough
for our purposes. (One needs to run functions repeatedly to extract reliable
benchmarks.)

# Basic Implementation

Having the building blocks (finding prime numbers, factorizing a single number)
together, an first implementation for the problem initially stated can be
provided: the module `Factorizer` (`lib/factorizer.ex`), which provides the
function `factorize/1`:

```elixir
defmodule Factorizer do
  def factorize(numbers) do
    Enum.map(numbers, fn n ->
      {n, PrimeFactors.factorize(n)}
    end)
    |> Map.new()
  end
end
```

The function `factorize/1` expects a single argument, which is a sequence of
unique numbers. These numbers are factorized using `PrimeFactors.factorize/1`,
which was in the section before. Each operation, which is performed using
`Enum.map/2`, returns a tuple consisting of the original number as the first
element, and the prime factors found as the second element. Those results are
transformed into a map with the original numbers as its keys and the found
factors as the values.

The module can be used as follows (e.g. with literal lists or ranges):

```elixir
> Factorizer.factorize([10, 20, 30])
%{10 => [2, 5], 20 => [2, 2, 5], 30 => [2, 3, 5]}

> Factorizer.factorize(10..15)
%{
  10 => [2, 5],
  11 => [11],
  12 => [2, 2, 3],
  13 => [13],
  14 => [2, 7],
  15 => [3, 5]
}
```

Factorizing a couple of big numbers in the range of $10^9$ now takes
considerable time:

```elixir
Stopwatch.timed(fn -> Factorizer.factorize(1_000_000_000..1_000_000_005) end)
2.40538s
%{
  1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  1000000001 => [7, 11, 13, 19, 52579],
  1000000002 => [2, 3, 43, 983, 3943],
  1000000003 => [23, 307, 141623],
  1000000004 => [2, 2, 41, 41, 148721],
  1000000005 => [3, 5, 66666667]
}
```

This timing of ~2.4 seconds shall be reduced by introducing concurrency, which
allows for parallel execution on a machine with multiple CPUs.

# Basic Parallel Implementation

The `Factorizer` module shall be rewritten using Elixir concurrency primitives
in order to speed up the process on a computer with multiple CPUs. In contrast
to the short and simple solution from above, the process is handled in multiple
stages:

1. Startup: Multiple processes are spawned.
2. Distribution: The numbers to be factorized are distributed to the running
   processes.
3. Collection: The results of the factorization are gathered to a overall
   result.

The `ParallelFactorizer` module has a single function `factorize/1`, which
expects a list of unique numbers and returns a map with those original numbers
(keys) mapped to their prime factors (values)—exactly like
`Factorizer.factorize/1`. However, the implementation is more involved.

First, one process per number is spawned:

```elixir
pids_by_number =
  Enum.map(numbers, fn n ->
    pid =
      spawn(fn ->
        receive do
          {caller, number} ->
            send(caller, {number, PrimeFactors.factorize(number)})
        end
      end)

    {n, pid}
  end)
  |> Map.new()
```

The `spawn/1` function expects a function to be run in a separate process. Here,
this function only expects a single message: A tuple consisting of the caller's
process id (PID), and the number to be factorized. A response is sent using the
`send/2` function, which expects a PID (here: the caller's PID), and a response,
which is a tuple of the original number and the prime factors found using
`PrimeFactors.factorize/1`.

The processes are spawned from the `Enum.map/2` higher-order function, which
returns a tuple for every number processed consisting of the original number and
a PID of the process that has been spawned to process said number. The resulting
enumeration of tuples is converted to a map, which allows for lookups of
processes by numbers.

TODO: distribution
TODO: collection

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
