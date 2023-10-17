defmodule PrimeFactors do
  def factorize(n) do
    primes = PrimeSieve.up_to(div(n, 2))
    next(primes, n, [])
  end

  defp next(_, 0, acc) do
    Enum.reverse(acc)
  end

  defp next([], n, []) do
    [n]
  end

  defp next([], _, acc) do
    Enum.reverse(acc)
  end

  defp next(factors, n, acc) do
    [h | t] = factors

    if rem(n, h) == 0 do
      next(factors, div(n, h), [h | acc])
    else
      next(t, n, acc)
    end
  end
end
