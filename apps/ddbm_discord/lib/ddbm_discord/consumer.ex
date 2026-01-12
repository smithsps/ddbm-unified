defmodule DdbmDiscord.Consumer do
  @moduledoc """
  Handles Discord gateway events from Nostrum.
  """

  use Nostrum.Consumer

  alias Nostrum.Api.Message

  @impl true
  def handle_event({:READY, data, _ws_state}) do
    IO.puts("==> Discord bot connected as #{data.user.username}")
  end

  @impl true
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!ping" ->
        Message.create(msg.channel_id, content: "Pong!")

      _ ->
        :ignore
    end
  end

  @impl true
  def handle_event(_event) do
    :noop
  end
end
