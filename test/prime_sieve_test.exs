defmodule PrimeSieveTest do
  use ExUnit.Case

  test "finds the first ten prime numbers" do
    assert PrimeSieve.first(10) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
  end

  test "finds prime numbers up to a certain number" do
    assert PrimeSieve.up_to(30) == [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
  end
end
