defmodule FactorizerClient do
  def factorize(numbers) do
    pids_by_index =
      Enum.reduce(0..(System.schedulers_online() - 1), %{}, fn i, acc ->
        Map.put(acc, i, FactorizerServer.start())
      end)

    Enum.reduce(numbers, 0, fn number, i ->
      index = rem(i, System.schedulers_online())
      pid = Map.get(pids_by_index, index)
      FactorizerServer.factorize(pid, number)
      i + 1
    end)

    Enum.reduce(numbers, %{}, fn _, acc ->
      receive do
        {number, factors} -> Map.put(acc, number, factors)
      end
    end)
  end
end
