defmodule DdbmDiscord.Consumer do
  @moduledoc """
  Handles Discord gateway events from Nostrum.
  """

  use Nostrum.Consumer
  require Logger

  alias DdbmDiscord.Commands.{Give, Token, TokenAdmin, Register, Unregister}

  @impl true
  def handle_event({:READY, data, _ws_state}) do
    Logger.info("Discord bot connected as #{data.user.username}")
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    handle_interaction(interaction)
  end

  @impl true
  def handle_event(_event) do
    :noop
  end

  defp handle_interaction(%{data: %{name: "give"}} = interaction) do
    Give.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "token"}} = interaction) do
    Token.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "token-admin"}} = interaction) do
    TokenAdmin.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "register"}} = interaction) do
    Register.execute(interaction)
  end

  defp handle_interaction(%{data: %{name: "unregister"}} = interaction) do
    Unregister.execute(interaction)
  end

  defp handle_interaction(interaction) do
    Logger.warning("Unknown command: #{inspect(interaction.data.name)}")
  end
end
