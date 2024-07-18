defmodule LeanCoffeeWeb.SessionLive.Index do
  use LeanCoffeeWeb, :live_view
  require Logger

  alias LeanCoffee.Storage
  alias MyAppWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(LeanCoffee.PubSub, "session:index")

    sessions = list_sessions()
    Logger.debug(inspect(sessions))
    socket = assign(socket, :sessions, sessions)
    Logger.debug(inspect(socket))
    {:ok, socket}
  end

  def handle_event("create_session", %{"name" => name}, socket) do
    Logger.info("*** pheonix handling create_session")
    id = UUID.uuid4()
    Storage.create_session(id, name)
    {:noreply, assign(socket, :sessions, list_sessions())}
  end

  def handle_info({:new_session, id, name}, socket) do
    Logger.info("got a new session #{name} #{id}")
    {:noreply, assign(socket, :sessions, list_sessions())}
  end

  defp list_sessions do
    sessions = Storage.get_all_sessions()
    Logger.debug("*** Listing Sessions: #{inspect(sessions)}")
    sessions
  end
end
