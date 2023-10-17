defmodule FactorizerTest do
  use ExUnit.Case
  doctest Factorizer

  test "greets the world" do
    assert Factorizer.hello() == :world
  end
end
