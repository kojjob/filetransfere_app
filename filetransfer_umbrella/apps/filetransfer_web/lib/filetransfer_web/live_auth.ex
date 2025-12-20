defmodule FiletransferWeb.LiveAuth do
  @moduledoc """
  Handles authentication for LiveView routes.

  This module provides on_mount hooks that load the current user
  from the session into socket assigns before LiveView mount callbacks.
  """
  import Phoenix.Component
  import Phoenix.LiveView
  alias FiletransferCore.Accounts

  @doc """
  on_mount hooks for LiveView authentication.

  ## Hooks

  - `:require_authenticated_user` - Requires authentication, loads current_user into socket
  - `:require_project_owner` - Requires project owner role
  - `:maybe_authenticated_user` - Loads user if present, but doesn't require authentication
  """
  def on_mount(:require_authenticated_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} when is_binary(user_id) ->
        case Accounts.get_user(user_id) do
          nil ->
            socket =
              socket
              |> put_flash(:error, "Invalid session. Please log in again.")
              |> redirect(to: "/login")

            {:halt, socket}

          user ->
            {:cont, assign(socket, :current_user, user)}
        end

      _ ->
        socket =
          socket
          |> put_flash(:error, "You must log in to access this page.")
          |> redirect(to: "/login")

        {:halt, socket}
    end
  end

  def on_mount(:require_project_owner, _params, session, socket) do
    # First ensure user is authenticated
    case on_mount(:require_authenticated_user, nil, session, socket) do
      {:halt, socket} ->
        {:halt, socket}

      {:cont, socket} ->
        # Check if user is a project owner
        user = socket.assigns.current_user

        if user.role == "project_owner" do
          {:cont, socket}
        else
          socket =
            socket
            |> put_flash(:error, "You do not have permission to access this page.")
            |> redirect(to: "/dashboard")

          {:halt, socket}
        end
    end
  end

  def on_mount(:maybe_authenticated_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} when is_binary(user_id) ->
        case Accounts.get_user(user_id) do
          nil ->
            {:cont, assign(socket, :current_user, nil)}

          user ->
            {:cont, assign(socket, :current_user, user)}
        end

      _ ->
        {:cont, assign(socket, :current_user, nil)}
    end
  end
end
