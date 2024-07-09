defmodule LeanCoffee.Storage do
  use GenServer

  @table_name :sessions

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_session(id, name) do
    :ets.insert(@table_name, {id, name, []})
  end

  def get_all_sessions do
    :ets.tab2list(@table_name)
  end

  def join_session(session_id, user) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants}] ->
        new_participants = Enum.uniq([user | participants])
        :ets.insert(@table_name, {session_id, name, new_participants})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:update_participants, session_id, new_participants}
        )

        {:ok, {session_id, name, new_participants}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def get_session(session_id) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants}] -> {:ok, {session_id, name, participants}}
      [] -> {:error, :session_not_found}
    end
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    :ets.new(@table_name, [:named_table, :public, :set])
    {:ok, %{}}
  end
end
