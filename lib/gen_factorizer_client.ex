defmodule GenFactorizerClient do
  def factorize(numbers) do
    # start one process per scheduler (i.e. one per CPU by default)
    scheds = System.schedulers_online()

    pids_by_index =
      Enum.reduce(0..(scheds - 1), %{}, fn i, acc ->
        {:ok, pid} = GenFactorizer.start()
        Map.put(acc, i, pid)
      end)

    # send one message per number (round robin server picking)
    result =
      Enum.reduce(numbers, {0, %{}}, fn number, {i, acc} ->
        pid = Map.get(pids_by_index, rem(i, scheds))
        GenFactorizer.factorize(pid, number)
        {i + 1, Map.put(acc, number, pid)}
      end)

    pids_by_number = elem(result, 1)

    # collect messages
    Enum.reduce(pids_by_number, %{}, fn {number, pid}, acc ->
      result = GenFactorizer.get_result(pid, number)

      case result do
        {:ok, factors} -> Map.put(acc, number, factors)
        {:err, msg} -> IO.puts(msg)
      end
    end)
  end
end
