# Factorizer

Experimenting with Elixir Concurrency using Prime Numbers.

## Code

- Common Modules
    - `Stopwatch` (`lib/stopwatch.ex`): provides `timed/1` to measure the
      execution time of a function.
    - `PrimeSieve` (`lib/prime_sieve.ex`): implements the _Sieve of
      Eratosthenes_ using a stream to return the `first/1` `n` prime numbers, or
      the prime numbers `up_to/1` `n`.
    - `PrimeFactors` (`lib/prime_factors.ex`): factorizes a number into their
      prime components using `PrimeSieve`.
- Basic Implementation
    - `Factorizer` (`lib/factorizer.ex`): provides `factorize/1`, which applies
      factorization using `PrimeFactors` to each element in the given list;
      returns a map of numbers (key) and their prime factors (values).
- Basic Parallel Implementation
    - `ParallelFactorizer` (`lib/parallel_factorizer.ex`): spawns one process
      per given number to factorize them in parallel.
- Client/Server Parallel Implementation
    - `FactorizerServer` (`lib/factorizer_server.ex`): provides a long-running
      server process to factorize numbers.
    - `FactorizerClient` (`lib/factorizer_client.ex`): spawns one server process
      per available scheduler (i.e. CPU core), to which numbers to be factorized
      are assigned using a round robin mechanism.
- Generic Client/Server Parallel Implementation using a Callback Module
    - `ServerProcess` (`lib/server_process.ex`): implements a generic, stateful
      server process that accepts synchronuous (call) and asynchronuous (cast)
      messages.
    - `FactorizerCallback` (`lib/factorizer_callback.ex`): implements the
      specific logic of the factorization to work with the generic
      `ServerProcess`. Numbers to be factorized are submitted using a
      synchronuous call and retrieved using a asynchronuous cast.
    - `FactorizerCallbackClient` (`lib/factorizer_callback_client.ex`): spawns
      one callback module (with a generic server process behind) to factorize
      the given prime numbers without implementing any concurrency mechanisms on
      its own.

## Execution

Start `iex` with the current mix project:

    $ iex -S mix

Factorize some numbers:

    > Stopwatch.timed(fn -> Factorizer.factorize(1_000_000_000..1_000_000_010) end)
    4.201577s
    %{
      1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
      1000000001 => [7, 11, 13, 19, 52579],
      1000000002 => [2, 3, 43, 983, 3943],
      1000000003 => [23, 307, 141623],
      1000000004 => [2, 2, 41, 41, 148721],
      1000000005 => [3, 5, 66666667],
      1000000006 => [2, 500000003],
      1000000007 => [1000000007],
      1000000008 => [2, 2, 2, 3, 3, 7, 109, 109, 167],
      1000000009 => [1000000009],
      1000000010 => [2, 5, 17, 5882353]
    }

Factorize the same numbers _in parallel_ (~ 2.5 seconds):

    > Stopwatch.timed(fn -> ParallelFactorizer.factorize(1_000_000_000..1_000_000_010) end)
    1.099281s
    %{
      1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
      1000000001 => [7, 11, 13, 19, 52579],
      1000000002 => [2, 3, 43, 983, 3943],
      1000000003 => [23, 307, 141623],
      1000000004 => [2, 2, 41, 41, 148721],
      1000000005 => [3, 5, 66666667],
      1000000006 => [2, 500000003],
      1000000007 => [1000000007],
      1000000008 => [2, 2, 2, 3, 3, 7, 109, 109, 167],
      1000000009 => [1000000009],
      1000000010 => [2, 5, 17, 5882353]
    }

Same again, but with one server process per scheduler (Round Robin):

    > Stopwatch.timed(fn -> FactorizerClient.factorize(1_000_000_000..1_000_000_010) end)
    1.207592s
    %{
      1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
      1000000001 => [7, 11, 13, 19, 52579],
      1000000002 => [2, 3, 43, 983, 3943],
      1000000003 => [23, 307, 141623],
      1000000004 => [2, 2, 41, 41, 148721],
      1000000005 => [3, 5, 66666667],
      1000000006 => [2, 500000003],
      1000000007 => [1000000007],
      1000000008 => [2, 2, 2, 3, 3, 7, 109, 109, 167],
      1000000009 => [1000000009],
      1000000010 => [2, 5, 17, 5882353]
    }

Same again, but implemented using a server process with a callback module:

    iex(2)> Stopwatch.timed(fn -> FactorizerCallbackClient.factorize(1_000_000_000..1_000_000_010) end)
    1.196734s
    %{
      1000000000 => [2, 2, 2, 2, 2, 2, 2, 2, 2, 5, 5, 5, 5, 5, 5, 5, 5, 5],
      1000000001 => [7, 11, 13, 19, 52579],
      1000000002 => [2, 3, 43, 983, 3943],
      1000000003 => [23, 307, 141623],
      1000000004 => [2, 2, 41, 41, 148721],
      1000000005 => [3, 5, 66666667],
      1000000006 => [2, 500000003],
      1000000007 => [1000000007],
      1000000008 => [2, 2, 2, 3, 3, 7, 109, 109, 167],
      1000000009 => [1000000009],
      1000000010 => [2, 5, 17, 5882353]
    }
