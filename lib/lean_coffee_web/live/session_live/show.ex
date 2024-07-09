defmodule LeanCoffeeWeb.SessionLive.Show do
  use LeanCoffeeWeb, :live_view

  alias LeanCoffee.Storage

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(LeanCoffee.PubSub, "session:#{id}")

    case Storage.get_session(id) do
      {:ok, {session_id, name, participants, topics}} ->
        {:ok,
         assign(socket,
           session_id: session_id,
           name: name,
           participants: participants,
           topics: topics,
           new_user: "",
           new_topic: ""
         )}

      {:error, :session_not_found} ->
        {:ok, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("join", %{"user" => user}, socket) do
    case Storage.join_session(socket.assigns.session_id, user) do
      {:ok, {_session_id, _name, participants, _topics}} ->
        {:noreply, assign(socket, participants: participants, new_user: "")}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("update_new_user", %{"user" => new_user}, socket) do
    {:noreply, assign(socket, new_user: new_user)}
  end

  def handle_event("propose_topic", %{"topic" => topic}, socket) do
    case Storage.propose_topic(socket.assigns.session_id, topic) do
      {:ok, {_session_id, _name, _participants, topics}} ->
        {:noreply, assign(socket, topics: topics, new_topic: "")}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("update_new_topic", %{"topic" => new_topic}, socket) do
    {:noreply, assign(socket, new_topic: new_topic)}
  end

  def handle_event("vote", %{"topic" => topic}, socket) do
    case Storage.vote_topic(socket.assigns.session_id, topic) do
      {:ok, {_session_id, _name, _participants, topics}} ->
        {:noreply, assign(socket, topics: topics)}

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
end
