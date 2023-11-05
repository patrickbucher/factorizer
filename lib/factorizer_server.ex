defmodule FactorizerServer do
  def start do
    spawn(&loop/0)
  end

  def factorize(server_pid, number) do
    send(server_pid, {self(), number})
  end

  defp loop do
    receive do
      {caller, number} ->
        send(caller, {number, PrimeFactors.factorize(number)})
    end

    loop()
  end
end
