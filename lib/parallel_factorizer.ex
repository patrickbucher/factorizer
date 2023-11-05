defmodule ParallelFactorizer do
  def factorize_parallel(numbers) do
    # start one process per number
    pids_by_number =
      Enum.map(numbers, fn n ->
        pid =
          spawn(fn ->
            receive do
              {caller, number} ->
                send(caller, {number, PrimeFactors.factorize(number)})
            end
          end)

        {n, pid}
      end)
      |> Map.new()

    # send one message per number
    Enum.each(pids_by_number, fn {number, pid} ->
      send(pid, {self(), number})
    end)

    # collect messages
    collect(Enum.map(numbers, fn n -> {n, []} end) |> Map.new(), %{})
  end

  defp collect(pending, acc) when map_size(pending) > 0 do
    receive do
      {number, factors} ->
        if Map.has_key?(pending, number) do
          collect(Map.drop(pending, [number]), Map.put(acc, number, factors))
        else
          collect(pending, acc)
        end
    end
  end

  defp collect(%{}, acc) do
    acc
  end
end
