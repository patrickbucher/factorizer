defmodule PrimeFactors do
  def factorize(n) do
    primes = PrimeSieve.up_to(:math.sqrt(n))
    next(primes, n, [])
  end

  defp next(_, 0, acc) do
    Enum.reverse(acc)
  end

  defp next([], 1, acc) do
    Enum.reverse(acc)
  end

  defp next([], n, acc) do
    Enum.reverse([n | acc])
  end

  defp next(primes, n, acc) do
    [h | t] = primes

    if rem(n, h) == 0 do
      next(primes, div(n, h), [h | acc])
    else
      next(t, n, acc)
    end
  end
end
