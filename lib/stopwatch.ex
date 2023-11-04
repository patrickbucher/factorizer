defmodule Stopwatch do
  def timed(fun) do
    {time, value} = :timer.tc(fun)
    seconds = time / 1.0e6
    IO.puts("#{seconds}s")
    value
  end
end
