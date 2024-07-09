defmodule LeanCoffeeWeb.SessionLive.Show do
  use LeanCoffeeWeb, :live_view

  alias LeanCoffee.Storage

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(LeanCoffee.PubSub, "session:#{id}")

    case Storage.get_session(id) do
      {:ok, {session_id, name, participants}} ->
        {:ok,
         assign(socket,
           session_id: session_id,
           name: name,
           participants: participants,
           new_user: ""
         )}

      {:error, :session_not_found} ->
        {:ok, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("join", %{"user" => user}, socket) do
    case Storage.join_session(socket.assigns.session_id, user) do
      {:ok, {_session_id, _name, participants}} ->
        {:noreply, assign(socket, participants: participants, new_user: "")}

      {:error, :session_not_found} ->
        {:noreply, socket |> put_flash(:error, "Session not found") |> redirect(to: "/")}
    end
  end

  def handle_event("update_new_user", %{"user" => new_user}, socket) do
    {:noreply, assign(socket, new_user: new_user)}
  end

  def handle_info({:update_participants, _session_id, participants}, socket) do
    {:noreply, assign(socket, participants: participants)}
  end
end
