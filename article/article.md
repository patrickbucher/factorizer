---
title: 'Concurrent Prime Factorization'
subtitle: 'A Go Programmer Learns Elixir Concurrency'
author: 'Patrick Bucher, Composed GmbH'
---

The concurrency model used in Elixir (and Erlang), often referred to as the
_Actor Model_, is quite similar to the model used in Go, which is called
_Communicating Sequential Processes_. There are many things in common, indeed:

- Both Elixir's (or Erlang's) _processes_ and Go's _goroutines_ are
  lightweight. It's practical to have hundreds or even thousands of them
  running, which are mapped to operating system threads in a _n:m_ manner (_n_
  OS threads running _m_ processes/goroutines).
- Both models facilitate message passing between concurrent units of execution
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
- Knowing a process's PID is sufficient to send a message to it in Elixir,
  whereas in Go channels known to both goroutines are required for communication
  between them.
- As a consequence, a goroutine can wait for a message from a specific channel
  (possibly only known to another specific goroutine), whereas in Elixir a
  process can just wait for any incoming message being sent from any other
  process.
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
|   $12$ |     $2, 2, 3$ |            $2 \times 2 \times 3 = 12$ |
|   $13$ |          $13$ |                             $13 = 13$ |
|   $24$ |  $2, 2, 2, 3$ |   $2 \times 2 \times 2 \times 3 = 24$ |
|   $30$ |     $2, 3, 5$ |            $2 \times 3 \times 5 = 30$ |
|  $140$ |  $2, 2, 5, 7$ |  $2 \times 2 \times 5 \times 7 = 140$ |
|  $580$ | $2, 2, 5, 29$ | $2 \times 2 \times 5 \times 29 = 580$ |

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
individual factorizations can be performed independently.

The prime factorization of a sequence of natural numbers is therefore a problem
well suited for a case study in CPU-bound concurrency.

# Building Blocks

The algorithm described in the section above shall be implemented in a new
Elixir project, which is created using the `mix` tool (using Elixir version
1.15.7):

    $ mix new factorizer

This creates a scaffold in the folder `factorizer/` with source code files in
the `lib/` sub-folder, and test cases in `test/`. A module called `Factorizer`
is already provided in `lib/factorizer.ex`, which shall be implemented right
after the building blocks have been provided in the next step.

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
`n` is a prime number, which is both returned as the next element of the stream
and as the head of the updated accumulator.

Why is a number $n$ only checked for divisability by _prime_ numbers $p < n$ and
not by _all_ numbers $m < n$? Because if $n$ is not divisible by $m$, it won't
be divisible by $m^2$. E.g. if $13$ is not divisible by $2$, how could it be
divisible by $4=2^2$, which is the same as being divisible by $2$ _twice_?

A further optimization would be to filter `primes` to $p <= \frac{n}{2}$,
because no $p > \frac{n}{2}$ could divide $n$ such that the result would be a
natural number (e.g. $13 \div 7 < 1$). This is left as an exercise to the
reader. (Note that `primes` is built up in _descending_ order, i.e. new elements
are added at its head.)

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
defp next(1, _, acc) do
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
the empty list. So in every step, both cases are reduced towards one of the two
base cases explained above.

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
other arbitrary code), the `Stopwatch` module (`lib/stopwatch.ex`) is provided:

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
together, a first implementation for the problem initially stated is provided as
the module `Factorizer` (`lib/factorizer.ex`), which provides the function
`factorize/1`:

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
explained in the section before. Each operation, which is performed using
`Enum.map/2`, returns a tuple consisting of the original number as the first
element, and the prime factors found as the second element. Those results are
transformed into a map with the original numbers as its keys and the found
factors as the values.

The module can be used as follows (e.g. with list literals or ranges):

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
> Stopwatch.timed(fn -> Factorizer.factorize(1_000_000_000..1_000_000_005) end)
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

The `Factorizer` module shall be rewritten using Elixir's concurrency primitives
in order to speed up the process on a computer with multiple CPUs. In contrast
to the short and simple solution from above, the concurrent computation is
handled in multiple stages:

1. _Startup_: Multiple processes are spawned, one per number to be processed.
2. _Distribution_: The numbers to be factorized are distributed to the running
   processes.
3. _Collection_: The results of the factorizations are gathered to an overall
   result.

The `ParallelFactorizer` (`lib/parallel_factorizer.ex`) module has a single
function `factorize/1`, which expects a list of unique numbers and returns a
map with those numbers (keys) mapped to their prime factors (values)—exactly
like `Factorizer.factorize/1`. However, the implementation is more involved.

First, one process per number is spawned:

```elixir
pids_by_number =
  Enum.map(numbers, fn n ->
    pid = spawn(&handle/0)
    {n, pid}
  end)
  |> Map.new()
```

The processes are spawned from the `Enum.map/2` higher-order function, which
returns a tuple for every number processed consisting of the original number and
a PID of the process that has been spawned to factorize said number. The
resulting enumeration of tuples is converted to a map, which allows for lookups
of processes by numbers.

The `spawn/1` function, which starts a child process, expects a function to be
run concurrently. Here, the `handle/1` function is passed, which is defined as
follows:

```elixir
defp handle() do
  receive do
    {caller, number} ->
      send(caller, {number, PrimeFactors.factorize(number)})
  end
end
```

This function can only handle one kind of message: A tuple consisting of the
caller's process id (PID), and the number to be factorized. A response is sent
to the caller using the `send/2` function, which expects a PID (here: the
caller's PID) and a response, which is a tuple of the original number and the
prime factors found using `PrimeFactors.factorize/1`.

Note that no work has been assigned to the spawned processes yet. They first
have to be activated by sending them a message, which happens in the next step:

```elixir
Enum.each(pids_by_number, fn {number, pid} ->
  send(pid, {self(), number})
end)
```

The map of PIDs by number is now processed. A message consisting of the main
process's PID (accessed using the `self/0` function), to which responses shall
be sent, and the number to be factorized is sent over to the respective process.

The work is now distributed, and the main process will receive their results in
the order of their computation:

```elixir
Enum.reduce(numbers, %{}, fn _, acc ->
  receive do
    {number, factors} -> Map.put(acc, number, factors)
  end
end)
```

The `Enum.reduce/3` higher-order function is used to process the numbers.
However, the numbers themselves are not even of interest: It's only important
that one message per number is received. The reduction starts with the empty map
`%{}` to be used as the accumulator (`acc`), which is filled with the incoming
results. For every message that is received—consisting of the original number
and its prime factors found—the map is extended with that number as the key and
the prime factors found as the value. This resulting map is also the result of
the `factorize/1` function.

The first two steps (spawning processes and distributing the work to them)
could have been handled within a single iteration instead of the two being
performed in the implementation just described. However, the separation into two
phases makes the conceptual phases more congruent with the layout of the code
and its actual execution.

The computation has been sped up considerably:

```elixir
> Stopwatch.timed(fn -> ParallelFactorizer.factorize(1_000_000_000..1_000_000_005) end)
0.643088s
%{
  1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  # ...
  1000000005 => [3, 5, 66666667]
}
```

From ~2.4 to ~0.64 seconds, which is roughly a fourfold improvement—no surprise
on a computer with four CPU cores.

# Client/Server Implementation

Elixir processes are lightweight, therefore it's not an issue to spawn many of
them, i.e. one per unit of work (such as a number to be factorized). However,
with `n` CPUs given, no more than `n` processes will run at the same time.
Instead of spawning one process for each number to be factorized, one
long-running process per CPU can be spawned. The work is then distributed to
those _server processes_, which accept and process messages in a loop.

First, let's have a look at the server process implemented in its own module
`FactorizerServer` (`lib/factorizer_server.ex`):

```elixir
defmodule FactorizerServer do
  def start do
    spawn(&loop/0)
  end

  def factorize(server_pid, number) do
    send(server_pid, {self(), number})
  end

  defp loop do
    receive do
      {caller, number} ->
        send(caller, {number, PrimeFactors.factorize(number)})
    end

    loop()
  end
end
```

The server process is created using the `start/0` function, which spawns a new
process and returns its PID. (The server runs the `loop/0` function, which
processes incoming messages.) Using that PID, a client can call the
`factorize/2` function with an additional argument: the number to be factorized.
A message is sent to the respective process, which is then processed in `loop/0`
by factorizing the number and sending it back with the computed result to the
caller. The `loop/0` function calls itself to await the next message.

Note that `start/0` and `factorize/2` run within the client process; only
`loop/0` runs in the spawned server process. `FactorizerServer` abstracts the
concurrency details to some degree from its client, which is implemented in the
module `FactorizerClient` (`lib/factorizer_client.ex`), consisting only of a
single function `factorize/1`—just like the two implementations discussed
before.

The concurrent prime factorization is performed in three phases again. First,
the server processes are spawned, but this time, only one process per available
CPU:

```elixir
pids_by_index =
  Enum.reduce(0..(System.schedulers_online() - 1), %{}, fn i, acc ->
    Map.put(acc, i, FactorizerServer.start())
  end)
```

The sequence of $[0..n[$, with $n$ representing the number of CPUs (Elixir uses
one scheduler per CPU), is processed. In each step, the spawned server process's
PID is put into a map as the value with the index $[0..n[$ as its key.

In the second phase, the work is distributed to the processes using round robin
scheduling:

```elixir
Enum.reduce(numbers, 0, fn number, i ->
  index = rem(i, System.schedulers_online())
  pid = Map.get(pids_by_index, index)
  FactorizerServer.factorize(pid, number)
  i + 1
end)
```

The numbers to be factorized are processed using `Enum.reduce/3`. Starting with
an accumulator of 0, the PID's index is computed using a modulo operation, which
is then used to retrieve the proper PID from the map.
`FactorizerServer.factorize/2` is called with the PID thus found and the number
to be processed. The index is incremented so that another server process's PID
will be picked for the next number.

In the third and final phase, the incoming results are gathered in a map, which
is returned as the result of the entire factorization process:

```elixir
Enum.reduce(numbers, %{}, fn _, acc ->
  receive do
    {number, factors} -> Map.put(acc, number, factors)
  end
end)
```

The performance is comparable to the first concurrent implementation:

```elixir
> Stopwatch.timed(fn -> FactorizerClient.factorize(1_000_000_000..1_000_000_005) end)
0.640536s
%{
  1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  # ...
}
```

With four CPUs available, factorizing six numbers in either six or four
processes hardly makes any difference in overhead. (The overhead becomes
apparent as more numbers are processed, though.)

# Callback Implementation

The client/server implementation not only abstracted some messaging details, it
also introduced long-running processes using a tail call `loop/0` function. This
pattern can be used to introduce state, which is advanced by calling such a
`loop` function with an updated argument.

Furthermore, the domain-specific code can be separated from the messaging
details by splitting up the server process into a _generic part_ and a _callback
module_. A generic server process provides the following operations:

- A `start/1` function that expects a callback module as its sole argument and
  spawns a new process. The initial state is provided by the callback module's
  `init/0` function. The (private) `loop/2` function is then called with both
  the callback module and the initial state. The PID of the spawned process is
  returned.
- A `cast/2` function that expects a PID and a request to be dealt with
  asynchronuously.
- A `call/2` function that also expects a PID and a request, which is dealt with
  synchronuously.
- A private `loop/2` function expecting a callback module and a state. This
  function deals with incoming messages—both asynchronuous cast and synchronuous
  call messages—by updating its received state, which is passed by a
  tail-recursive call to itself.

## The Server Module

The `ServerProcess` module (`lib/server_process.ex`) is devoid of any
domain-specific code (prime number factorization). Instead, it relies on a
callback module to perform the domain-specific task. The functions described
above are implemented as follows:

```elixir
def start(callback_module) do
  spawn(fn ->
    initial_state = callback_module.init()
    loop(callback_module, initial_state)
  end)
end
```

The initial state is computed in a seperate process, which then continues
running the loop based on that state. The returned PID is used by the caller to
invoke `cast/2` and `call/2` functions:

```elixir
def cast(server_pid, request) do
  send(server_pid, {:cast, request})
end

def call(server_pid, request) do
  send(server_pid, {:call, request, self()})

  receive do
    {:response, response} -> response
  end
end
```

Both operations expect a PID and a request. The asynchronuous `cast` function
just forwards the request to the server process, wrapping it as a `:cast`
message. The synchronuous `call` function also forwards the request (wrapped as
a `:call`) to the server process, but also provides its PID so that an answer
can be provided synchronuously. This answer is awaited using `receive` and
returned to the caller of the `call/2` function.

The `loop/2` function, both dealing with `:cast` and `:call` requests in its own
process, is implemented as follows:

```elixir
defp loop(callback_module, current_state) do
  receive do
    {:cast, request} ->
      new_state =
        callback_module.handle_cast(request, current_state)

      loop(callback_module, new_state)

    {:call, request, caller} ->
      {response, new_state} =
        callback_module.handle_call(request, current_state)

      send(caller, {:response, response})
      loop(callback_module, new_state)
  end
```

Both `:cast` and `:call` requests are dealt with by calling the respective
functions (`handle_cast/2` and `handle_call/2`) on the callback module. However,
`:cast` messages only advance the state using a tail call to `loop/2`, whereas
`:call` messages are also answered with an immediate message back to the caller
before the loop is invoked with the updated state.

## The Callback Module

The callback module, referred to as `callback_module` from various functions in
`ServerProcess`, is implemented in `FactorizerCallback`
(`lib/factorizer_callback.ex`). It provides two kinds of functions:

1. Domain functions offering an interface to a client, hiding the messaging
   details by dealing with the server process on its own.
2. Generic functions `init/0`, `handle_cast/2`, and `/handle_call/2`, which are
   used from the server process and deal with messaging.

The `init/0` function provides the initial state to the server process, which
is an empty map:

```elixir
def init do
  %{}
end
```

The `handle_cast/2` function deals with asynchronuous messages:

```elixir
def handle_cast({:factorize, number}, state) do
  Map.put(state, number, PrimeFactors.factorize(number))
end
```

Messages consisting of the symbol `:factorize` and a number are processed by
updating the given `state` with the prime factors of the given number. This
function is run inside the server process. The return value is used as the
server process's new state, but nothing is returned from the client.

Synchronuous messages are dealt with by the `handle_call/2` function:

```elixir
def handle_call({:get_result, number}, state) do
  if Map.has_key?(state, number) do
    {{:ok, Map.get(state, number)}, state}
  else
    {{:err, "no result for #{number}"}, state}
  end
end
```

The client can request a result of a factorization that already happened
asynchronuously. If the result is contained in the map, its prime factors are
returned. Otherwise, an error is returned. This interface allows for processing
the numbers in two phases: First, the numbers to be factorized are submitted
using asynchronuous cast messages. Second, the results of the factorizations
are retrieved synchronuously using call messages.

The domain functions provide a convenient interface for that purpose. Note that
handling state is not strictly necessary to solve the problem at hand. However,
it is handled in a safe way and could be used to implement a caching mechanism
later on.

The function `start/0` delegates the spawning of a new process to
`ServerProcess`:

```elixir
def start do
  ServerProcess.start(FactorizerCallback)
end
```

A number can be submitted for asynchronuous factorization using the
`factorize/2` function, which expects a PID (of the server process spawned
using `start/0`) and the number.

```elixir
def factorize(pid, number) do
  ServerProcess.cast(pid, {:factorize, number})
end
```

The result of a factorization can be retrieved using `get_result/2`, again
providing a PID and the number for which the result shall be retrieved:

```elixir
def get_result(pid, number) do
  ServerProcess.call(pid, {:get_result, number})
end
```

## Callback Client

Having a server process dealing with messaging details and a callback module
providing a domain-specific interface to the concurrent computations, only a
client is needed making use of those facilities. This client is implemented as
the module `FactorizerCallbackClient` (`lib/factorizer_callback_client.ex`).

As in the other concurrent implementations, the process is handled in the same
three phases—startup, distribution, and collection. A function `factorize/1` is
provided again, which is implemented as follows.

First, one server per CPU/scheduler is started; this time using the
`FactorizerCallback` module:

```elixir
pids_by_index =
  Enum.reduce(0..(System.schedulers_online() - 1), %{}, fn i, acc ->
    Map.put(acc, i, FactorizerCallback.start())
  end)
```

Second, the work is distributed to the processes using round robin scheduling
and the asynchronuous `factorize/2` function, and the PIDs are stored as the
values in a map, indexed by the numbers they factorize. Again, the
`FactorizerCallback` module is used, which hides the messaging details:

```elixir
result =
  Enum.reduce(numbers, {0, %{}}, fn number, {i, acc} ->
    pid = Map.get(pids_by_index, rem(i, System.schedulers_online()))
    FactorizerCallback.factorize(pid, number)
    {i + 1, Map.put(acc, number, pid)}
  end)

pids_by_number = elem(result, 1)
```

Third, the results are collected into a map using the synchronuous
`get_result/2` function. A simple error handling mechanism is implemented,
sending potential errors to the standard output:

```elixir
Enum.reduce(pids_by_number, %{}, fn {number, pid}, acc ->
  result = FactorizerCallback.get_result(pid, number)

  case result do
    {:ok, factors} -> Map.put(acc, number, factors)
    {:err, msg} -> IO.puts(msg)
  end
end)
```

This code is not shorter compared to the preceeding concurrent implementation,
but devoid of any message handling, which is all dealt with in  the
`FactorizerCallback` module working tightly together with the `ServerProcess`
module.

Actually, `FactorizerCallbackClient.factorize/1` is slightly longer and more
involved than `FactorizerClient.factorize/1`, _because_ the messaging details
are abstracted away by `ServerProcess`: Instead of awaiting messages arriving at
the controlling process's letterbox, the spawned PIDs have to kept track of in
order to receive results from their computations synchronuously. (This is
somewhat closer to implementations using to Go's concurrency model, in which
results are expected from particular channels.)

Performance is hardly affected by the communication overhead of the two modules
`ServerProcess` and `FactorizerCallback` working tightly together:

```elixir
> Stopwatch.timed(
    fn -> FactorizerCallbackClient.factorize(1_000_000_000..1_000_000_005)
  end)
0.648022s
%{
  1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
  # ...
}
```

# GenServer Implementation

The `ServerProcess` module just discussed is so generic that Elixir actually
provides such a module called `GenServer` (generic server), which is one of many
so-called _OTP Behaviours_. Instead of writing a `ServerProcess` on one's own, a
callback module implementing the functions `init/1`, `handle_cast/2`, and
`handle_call/2` can simply make use of `GenServer`, as it's done in the
`GenFactorizer` module (`lib/gen_factorizer.ex`):

```elixir
defmodule GenFactorizer do
  use GenServer
  # ...
end
```

The `init/1` function provides the initial state:

```elixir
@impl GenServer
def init(_) do
  {:ok, %{}}
end
```

Note that `init` expects an argument, which is ignored in this implementation.
The response is also tagged with the symbol `:ok`, which is a requirement of the
`GenServer` behaviour. The `@impl` module attribute ensures compliance with
`GenServer` by emitting warnings at compile time.

Asynchronuous messages are handled by `handle_cast/2`:

```elixir
@impl GenServer
def handle_cast({:factorize, number}, state) do
  {:noreply, Map.put(state, number, PrimeFactors.factorize(number))}
end
```

This implementation is almost identical to the one provided by
`FactorizerCallback` further above, but the new state is also tagged with a
symbol (here: `:noreply`).

Synchronuous messages handled by `handle_call/2` look similar to the last
implementation, too:

```elixir
@impl GenServer
def handle_call({:get_result, number}, _, state) do
  if Map.has_key?(state, number) do
    {:reply, {:ok, Map.get(state, number)}, state}
  else
    {:reply, {:err, "no result for #{number}"}, state}
  end
end
```

The second argument, which is not used in this example, can be used to identify
the caller process and the message, as described in the [API
documentation](https://hexdocs.pm/elixir/1.15/GenServer.html#c:handle_call/3).
Once more, the result is tagged with a symbol (here: `:reply`).

So much for the callback methods, which all are annotated with a `@impl
GenServer` module attribute and decorate their return values with a symbol.

The other part of `GenFactorizer` provides the API for the client. This
implementation is almost identical to the one provided by `FactorizerCallback`:

```elixir
def start do
  GenServer.start(__MODULE__, nil)
end

def factorize(pid, number) do
  GenServer.cast(pid, {:factorize, number})
end

def get_result(pid, number) do
  GenServer.call(pid, {:get_result, number}, 10_000)
end
```

The `start/0` function provides the current module's name to `GenServer.start/2`
using `__MODULE__` instead of spelling out its own module name, which allows for
more convenient renaming of the module `GenFactorizer`, since the name must only
be changed at a single place. A second argument required by `GenServer.start/2`
is just given as `nil`. Note that `GenServer.call/3` is used, i.e. with an
additional timeout argument, which is set to ten seconds. If the answer doesn't
arrive within that timeout, an error is raised.

The client, implemented as `GenFactorizerClient`
(`lib/gen_factorizer_client.ex`), is almost identical to the
`FactorizerCallbackClient` discussed above. The only difference is that the
former makes use of the callback module `GenFactorizer` while the latter uses
the `FactorizerCallback` module.

# Timings

The five implementations of prime factorization—one non-concurrent, four 
concurrent—are tested with numbers from $10^9$ upwards using the
`Stopwatch.timed/1` function. The rows denote the implementations discussed
above; the columns denote the amount of numbers tested. The benchmarks have been
executed on a AMD Ryzen 5 PRO 3400GE CPU (four cores, eight threads). The
results are not proper benchmarks, but should give a rough idea about the
relative performance of those implementations:

| Implementation / $n$ |    $1$ |   $10$ |  $100$ |
|----------------------|-------:|-------:|-------:|
| Basic                | $0.41$ | $3.87$ | $39.0$ |
| Parallel             | $0.39$ | $0.99$ | $10.7$ |
| Client/Server        | $0.39$ | $1.15$ | $9.02$ |
| Callback             | $0.39$ | $1.14$ | $9.05$ |
| GenServer            | $0.39$ | $1.14$ | $9.09$ |

Besides the expected four-fold speedup between the basic implementation on one
hand and the parallel implementations on the other hand, there's also a speedup
between the first parallel implementation (spawning one process per number) and
the three others (working with a process pool; one process per scheduler) as $n$
increases.

# Conclusion

It has been shown how a computationally expensive task can be sped up by
applying Elixir's concurrency features to the problem of prime factorization.
The solution has further been refined by separating the concerns—providing
facilities for concurrent computations and domain-specific code for making use
of them. Furthermore, the solution was adapted to Elixir's built-in OTP
facilities, which provide benefits far beyond what has been discussed in these
pages.

However, one has to keep in mind that using convenient concurrency features in
combination with the computing power of multi-core machines is not sufficient
and maybe not appropriate for every problem. In this example, the _same_ prime
numbers are computed time and again: concurrently, in parallel—and redundantly.
Using the exposed stream of prime numbers for consumption upon factorization or
implementing a memoization mechanism would arguably cause an additional speedup
to the one already gained.

Implementing a stateful process for finding prime numbers to avoid redundant
computations is left as an exercise to the reader. Applying concurrency is not
enough; one has to apply it at the proper place and in the right way.

# Sources and Links

- [github.com/patrickbucher/factorizer](https://github.com/patrickbucher/factorizer)
  containing both the executable code and this article
- Saša Jurić: _Elixir in Action_ (Second Edition), Manning 2019, ISBN-13: 9781617295027.
  This article describes an extended example for the mechanisms being explained
  in the chapters 5 and 6 of this very instructive book. (Its third edition will
  be released soon.)

When referring to "Elixir's concurrency features", as done many times in this
text, most of the credit goes to Erlang/OTP. Credit for providing a convenient
and attractive programming language on top of Erlang/OTP goes to the Elixir
team.
