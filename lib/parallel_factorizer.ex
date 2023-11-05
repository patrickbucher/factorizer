defmodule ParallelFactorizer do
  def factorize(numbers) do
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
    Enum.reduce(numbers, %{}, fn _, acc ->
      receive do
        {number, factors} -> Map.put(acc, number, factors)
      end
    end)
  end
end
