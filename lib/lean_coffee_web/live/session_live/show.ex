defmodule LeanCoffeeWeb.SessionLive.Show do
  use LeanCoffeeWeb, :live_view

  alias LeanCoffee.Storage

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(LeanCoffee.PubSub, "session:#{id}")

    case Storage.get_session(id) do
      {:ok, {session_id, name, participants, topics, current_topic, _time_ref}} ->
        {:ok,
         assign(socket,
           session_id: session_id,
           name: name,
           participants: participants,
           topics: topics,
           current_topic: current_topic,
           user_name: nil,
           new_topic: "",
           discussion_time: 5
         )}

      {:error, :session_not_found} ->
        {:ok, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("submit_user_name", %{"user_name" => user_name}, socket) do
    user_name = String.trim(user_name)

    if user_name == "" do
      {:noreply, socket |> put_flash(:error, "Name cannot be empty")}
    else
      case Storage.join_session(socket.assigns.session_id, user_name) do
        {:ok, {session_id, _name, participants, topics, current_topic, _timer_ref}} ->
          {:noreply, assign(socket, participants: participants, user_name: user_name)}

        {:error, :session_not_found} ->
          {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
      end
    end
  end

  def handle_event("update_user_name", %{"user_name" => user_name}, socket) do
    {:noreply, assign(socket, user_name: user_name)}
  end

  def handle_event("update_new_topic", %{"new_topic" => new_topic}, socket) do
    {:noreply, assign(socket, new_topic: new_topic)}
  end

  def handle_event("propose_topic", %{"new_topic" => topic}, socket) do
    user_name = socket.assigns.user_name

    if user_name == "" do
      {:noreply, socket |> put_flash(:error, "Please enter your name before proposing a topic.")}
    else
      case Storage.propose_topic(socket.assigns.session_id, topic, user_name) do
        {:ok, {_session_id, _name, _participants, topics, _current_topic, _timer_ref}} ->
          {:noreply, assign(socket, topics: topics, new_topic: "")}

        {:error, :session_not_found} ->
          {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
      end
    end
  end

  def handle_event("vote", %{"topic" => topic}, socket) do
    case Storage.vote_topic(socket.assigns.session_id, topic) do
      {:ok, {_session_id, _name, _participants, topics, _current_topic, _timer_ref}} ->
        {:noreply, assign(socket, topics: topics)}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("start_discussion", %{"topic" => topic}, socket) do
    IO.puts("***** starting discussion #{topic}")

    case Storage.start_discussion(socket.assigns.session_id, topic) do
      {:ok, {_session_id, _name, _participants, _topics, current_topic, _timer_ref}} ->
        {:noreply, assign(socket, current_topic: current_topic)}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("end_discussion", _params, socket) do
    IO.puts("***** ending discussion")

    case Storage.end_discussion(socket.assigns.session_id) do
      {:ok, {_session_id, _name, _participants, _topics, _current_topic, _timer_ref}} ->
        {:noreply, assign(socket, current_topic: nil)}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_info({:update_participants, _session_id, participants}, socket) do
    {:noreply, assign(socket, participants: participants)}
  end

  def handle_info({:new_topic, _session_id, topics}, socket) do
    {:noreply, assign(socket, topics: topics)}
  end

  def handle_info({:update_topics, _session_id, topics}, socket) do
    {:noreply, assign(socket, topics: topics)}
  end

  def handle_info({:start_discussion, _session_id, topic}, socket) do
    {:noreply, assign(socket, current_topic: topic)}
  end

  def handle_info({:end_discussion, _session_id, _topic}, socket) do
    {:noreply, assign(socket, current_topic: nil)}
  end
end
