defmodule LeanCoffeeWeb.SessionLive.Index do
  use LeanCoffeeWeb, :live_view

  alias LeanCoffee.Storage

  def mount(_params, _session, socket) do
    {:ok, assign(socket, sessions: list_sessions())}
  end

  def handle_event("create_session", %{"name" => name}, socket) do
    id = UUID.uuid4()
    Storage.create_session(id, name)
    {:noreply, assign(socket, sessions: list_sessions())}
  end

  defp list_sessions do
    sessions = Storage.get_all_sessions()
    IO.puts(inspect(sessions))
    sessions
  end
end
