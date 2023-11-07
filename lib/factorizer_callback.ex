defmodule FactorizerCallback do
  def start do
    ServerProcess.start(FactorizerCallback)
  end

  def factorize(pid, number) do
    ServerProcess.cast(pid, {:factorize, number})
  end

  def get_result(pid, number) do
    ServerProcess.call(pid, {:get_result, number})
  end

  def init do
    %{}
  end

  def handle_cast({:factorize, number}, state) do
    Map.put(state, number, PrimeFactors.factorize(number))
  end

  def handle_call({:get_result, number}, state) do
    if Map.has_key?(state, number) do
      {{:ok, Map.get(state, number)}, state}
    else
      {{:err, "no result for #{number}"}, state}
    end
  end
end
