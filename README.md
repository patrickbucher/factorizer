# Factorizer

Experimenting with Elixir Concurrency using Prime Numbers.

## Example

Start `iex` with the current mix project:

    $ iex -S mix

Factorize some numbers (~ 10 seconds):

    > Stopwatch.timed(fn -> Factorizer.factorize(100_000..100_010) end)
    9.882249s
    %{
      100000 => [2, 2, 2, 2, 2, 5, 5, 5, 5, 5],
      100001 => [11, 9091],
      100002 => [2, 3, 7, 2381],
      100003 => [100003],
      100004 => [2, 2, 23, 1087],
      100005 => [3, 5, 59, 113],
      100006 => [2, 31, 1613],
      100007 => [97, 1031],
      100008 => [2, 2, 2, 3, 3, 3, 463],
      100009 => [7, 7, 13, 157],
      100010 => [2, 5, 73, 137]
    }

Factorize the same numbers _in parallel_ (~ 2.5 seconds):

    > Stopwatch.timed(fn -> Factorizer.factorize_parallel(100_000..100_010) end)
    2.513614s
    %{
      100000 => [2, 2, 2, 2, 2, 5, 5, 5, 5, 5],
      100001 => [11, 9091],
      100002 => [2, 3, 7, 2381],
      100003 => [100003],
      100004 => [2, 2, 23, 1087],
      100005 => [3, 5, 59, 113],
      100006 => [2, 31, 1613],
      100007 => [97, 1031],
      100008 => [2, 2, 2, 3, 3, 3, 463],
      100009 => [7, 7, 13, 157],
      100010 => [2, 5, 73, 137]
    }
