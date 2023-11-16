defmodule PrimeFactors do
  def factorize(n) do
    primes = PrimeSieve.up_to(:math.sqrt(n))
    next(n, primes, [])
  end

  defp next(1, [], acc) do
    Enum.reverse(acc)
  end

  defp next(n, [], acc) do
    Enum.reverse([n | acc])
  end

  defp next(n, [h | t], acc) do
    if rem(n, h) == 0 do
      next(div(n, h), [h | t], [h | acc])
    else
      next(n, t, acc)
    end
  end
end
