defmodule FactorizerClient do
  def factorize(numbers) do
    # start one process per scheduler (i.e. one per CPU by default)
    pids_by_index =
      Enum.reduce(0..(System.schedulers_online() - 1), %{}, fn i, acc ->
        Map.put(acc, i, FactorizerServer.start())
      end)

    # send one message per number (round robin server picking)
    Enum.reduce(numbers, 0, fn number, i ->
      index = rem(i, System.schedulers_online())
      pid = Map.get(pids_by_index, index)
      FactorizerServer.factorize(pid, number)
      i + 1
    end)

    # collect messages
    Enum.reduce(numbers, %{}, fn _, acc ->
      receive do
        {number, factors} -> Map.put(acc, number, factors)
      end
    end)
  end
end
