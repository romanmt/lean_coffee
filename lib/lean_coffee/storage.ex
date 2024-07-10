defmodule LeanCoffee.Storage do
  use GenServer

  @table_name :sessions

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_session(id, name) do
    :ets.insert(@table_name, {id, name, [], [], nil, nil})
    Phoenix.PubSub.broadcast(LeanCoffee.PubSub, "session:#{id}", {:new_session, id, name})
  end

  def get_all_sessions do
    :ets.tab2list(@table_name)
  end

  def join_session(session_id, user) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, current_topic, timer_ref}] ->
        new_participants = Enum.uniq([user | participants])

        :ets.insert(
          @table_name,
          {session_id, name, new_participants, topics, current_topic, timer_ref}
        )

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:update_participants, session_id, new_participants}
        )

        {:ok, {session_id, name, new_participants, topics, current_topic, timer_ref}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def propose_topic(session_id, topic, user) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, current_topic, timer_ref}] ->
        new_topics = [{topic, 0, user} | topics]

        :ets.insert(
          @table_name,
          {session_id, name, participants, new_topics, current_topic, timer_ref}
        )

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:new_topic, session_id, new_topics}
        )

        {:ok, {session_id, name, participants, new_topics, current_topic, timer_ref}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def vote_topic(session_id, topic) do
    IO.puts("**** voting on #{topic}")

    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, current_topic, timer_ref}] ->
        new_topics =
          Enum.map(topics, fn
            {^topic, votes, user} -> {topic, votes + 1, user}
            other -> other
          end)

        :ets.insert(
          @table_name,
          {session_id, name, participants, new_topics, current_topic, timer_ref}
        )

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:update_topics, session_id, new_topics}
        )

        {:ok, {session_id, name, participants, new_topics, current_topic, timer_ref}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def start_discussion(session_id, topic) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, _current_topic, _timer_ref}] ->
        # 5 minutes
        new_timer_ref = Process.send_after(self(), {:end_discussion, session_id}, 5 * 60 * 1000)
        :ets.insert(@table_name, {session_id, name, participants, topics, topic, new_timer_ref})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:start_discussion, session_id, topic}
        )

        {:ok, {session_id, name, participants, topics, topic, new_timer_ref}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def end_discussion(session_id) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, current_topic, _timer_ref}] ->
        :ets.insert(@table_name, {session_id, name, participants, topics, nil, nil})

        Phoenix.PubSub.broadcast(
          LeanCoffee.PubSub,
          "session:#{session_id}",
          {:end_discussion, session_id, current_topic}
        )

        {:ok, {session_id, name, participants, topics, nil, nil}}

      [] ->
        {:error, :session_not_found}
    end
  end

  def get_session(session_id) do
    case :ets.lookup(@table_name, session_id) do
      [{^session_id, name, participants, topics, current_topic, timer_ref}] ->
        {:ok, {session_id, name, participants, topics, current_topic, timer_ref}}

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

  @impl true
  def handle_info({:end_discussion, session_id}, state) do
    end_discussion(session_id)
    {:noreply, state}
  end
end
