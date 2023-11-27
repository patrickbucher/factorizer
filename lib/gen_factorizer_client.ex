defmodule GenFactorizerClient do
  def factorize(numbers) do
    pids_by_index =
      Enum.reduce(0..(System.schedulers_online() - 1), %{}, fn i, acc ->
        {:ok, pid} = GenFactorizer.start()
        Map.put(acc, i, pid)
      end)

    result =
      Enum.reduce(numbers, {0, %{}}, fn number, {i, acc} ->
        pid = Map.get(pids_by_index, rem(i, System.schedulers_online()))
        GenFactorizer.factorize(pid, number)
        {i + 1, Map.put(acc, number, pid)}
      end)

    pids_by_number = elem(result, 1)

    Enum.reduce(pids_by_number, %{}, fn {number, pid}, acc ->
      result = GenFactorizer.get_result(pid, number)

      case result do
        {:ok, factors} -> Map.put(acc, number, factors)
        {:err, msg} -> IO.puts(msg)
      end
    end)
  end
end
