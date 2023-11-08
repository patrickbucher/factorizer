defmodule GenFactorizer do
  use GenServer

  def start do
    GenServer.start(__MODULE__, nil)
  end

  def factorize(pid, number) do
    GenServer.cast(pid, {:factorize, number})
  end

  def get_result(pid, number) do
    GenServer.call(pid, {:get_result, number})
  end

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:factorize, number}, state) do
    {:noreply, Map.put(state, number, PrimeFactors.factorize(number))}
  end

  @impl GenServer
  def handle_call({:get_result, number}, _, state) do
    if Map.has_key?(state, number) do
      {:reply, {:ok, Map.get(state, number)}, state}
    else
      {:reply, {:err, "no result for #{number}"}, state}
    end
  end
end
