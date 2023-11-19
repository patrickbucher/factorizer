defmodule ParallelFactorizer do
  def factorize(numbers) do
    pids_by_number =
      Enum.map(numbers, fn n ->
        pid = spawn(&handle/0)
        {n, pid}
      end)
      |> Map.new()

    Enum.each(pids_by_number, fn {number, pid} ->
      send(pid, {self(), number})
    end)

    Enum.reduce(numbers, %{}, fn _, acc ->
      receive do
        {number, factors} -> Map.put(acc, number, factors)
      end
    end)
  end

  defp handle() do
    receive do
      {caller, number} ->
        send(caller, {number, PrimeFactors.factorize(number)})
    end
  end
end
