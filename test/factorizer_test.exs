defmodule FactorizerTest do
  use ExUnit.Case

  test "factorizes some numbers" do
    assert Factorizer.factorize([7, 10, 20, 30, 99]) == %{
             7 => [7],
             10 => [2, 5],
             20 => [2, 2, 5],
             30 => [2, 3, 5],
             99 => [3, 3, 11]
           }
  end
end
