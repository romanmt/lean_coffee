defmodule LeanCoffee.Storage do
  use GenServer

  @table_name :sessions

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_session(id, name) do
    :ets.insert(@table_name, {id, name, [], []})
    Phoenix.PubSub.broadcast(LeanCoffee.PubSub, "session:#{id}", {:new_session, id, name})
  end

  def get_all_sessions do
    :ets.tab2list(@table_name)
  end

  def join_session(session_id, user) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics}] ->
        new_participants = Enum.uniq([user | participants])
        :ets.insert(@table_name, {session_id, name, new_participants, topics})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:update_participants, session_id, new_participants}
        )

        {:ok, {session_id, name, new_participants, topics}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def propose_topic(session_id, topic) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics}] ->
        new_topics = [{topic, 0} | topics]
        :ets.insert(@table_name, {session_id, name, participants, new_topics})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:new_topic, session_id, new_topics}
        )

        {:ok, {session_id, name, participants, new_topics}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def vote_topic(session_id, topic) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics}] ->
        new_topics =
          Enum.map(topics, fn
            {^topic, votes} -> {topic, votes + 1}
            other -> other
          end)

        :ets.insert(@table_name, {session_id, name, participants, new_topics})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:update_topics, session_id, new_topics}
        )

        {:ok, {session_id, name, participants, new_topics}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def get_session(session_id) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics}] ->
        {:ok, {session_id, name, participants, topics}}

      [] ->
        {:error, :session_not_found}
    end
  end

  # Server (callbacks)

  @impl true
  def init(:ok) do
    :ets.new(@table_name, [:named_table, :public, :set])
    {:ok, %{}}
  end
end
