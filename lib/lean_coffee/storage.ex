defmodule LeanCoffee.Storage do
  use GenServer

  @table_name :sessions

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_session(id, name) do
    :ets.insert(@table_name, {id, name})
  end

  def get_all_sessions do
    :ets.tab2list(@table_name)
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    :ets.new(@table_name, [:named_table, :public, :set])
    {:ok, %{}}
  end
end
