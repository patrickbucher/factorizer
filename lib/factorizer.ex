defmodule Factorizer do
  def factorize(numbers) do
    Enum.map(numbers, fn n ->
      {n, PrimeFactors.factorize(n)}
    end)
    |> Map.new()
  end
end
