defmodule Plug.Upload.EventDispatcher do
  @moduledoc """
  Below are all of the events that can be dispatched by the EventDispatcher

  :plug_upload_started
  :plug_upload_successful
  :plug_upload_failed

  They will be dispatched in a tuple of the format {:plug_upload_status, {event, upload_meta_data}}

  These events can then be received with handlers, like this:

    def handle_info({:plug_upload_status, {:plug_upload_started, %{conn: %Plug.Conn{request_path: "/some_path"}, filename: file}}}, state) do
      .
      .
      .
      {:noreply, state}
    end
  """
  @server_name __MODULE__
  require Logger

  @events [
    :plug_upload_started,
    :plug_upload_successful,
    :plug_upload_failed
  ]

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(_args \\ []) do
    Registry.start_link(keys: :duplicate, name: @server_name)
  end

  def register_for_upload_events() do
    for e <- @events, do: register(e)
    :ok
  end

  def register(item, meta \\ nil)

  def register(item, meta) when is_binary(item) do
    item
    |> String.to_atom()
    |> register(meta)
  end

  def register(item, meta) when is_atom(item) and item in @events do
    Logger.debug("Successfully registerd #{item}")
    Registry.register(@server_name, item, meta)
  end

  def register(_item, _meta) do
    {:error, :unknown_event}
  end

  def unregister(item) when is_binary(item) do
    item
    |> String.to_atom()
    |> register()
  end

  def unregister(item) when is_atom(item) and item in @events do
    Registry.unregister(@server_name, item)
  end

  def unregister(_item) do
    {:error, :unknown_event}
  end

  defp log_dispatch(event) do
    Logger.debug(fn ->
      "#{__MODULE__}: Dispatching event '#{event}'
        }"
    end)
  end

  def dispatch(event) when is_atom(event), do: dispatch(event, [])

  def dispatch(event) do
    Logger.notice(
      "Not dispatching event #{inspect(event)}. Event must be in Atom format, or as a tuple such as {:event, meta_data}."
    )
  end

  def dispatch(event, event_meta) when is_atom(event) do
    log_dispatch(event)

    Registry.dispatch(@server_name, event, fn entries ->
      for {pid, meta} <- entries do
        Logger.debug(fn -> "=> #{inspect(pid)} #{inspect(meta)}" end)
        send(pid, {:plug_upload_status, {event, event_meta}})
      end
    end)
  end
end
