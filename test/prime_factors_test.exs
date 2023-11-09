defmodule PrimeFactorsTest do
  use ExUnit.Case

  test "factorize a prime number" do
    assert PrimeFactors.factorize(13) == [13]
  end

  test "factorize some power of two" do
    assert PrimeFactors.factorize(1024) == for(_ <- 1..10, do: 2)
  end

  test "factorize the number 500" do
    assert PrimeFactors.factorize(500) == [2, 2, 5, 5, 5]
  end
end
