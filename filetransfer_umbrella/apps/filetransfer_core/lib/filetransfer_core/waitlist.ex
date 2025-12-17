defmodule FiletransferCore.Waitlist do
  @moduledoc """
  The Waitlist context for managing waitlist entries.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Waitlist.WaitlistEntry

  @doc """
  Returns the list of waitlist entries.
  """
  def list_waitlist_entries do
    Repo.all(from(w in WaitlistEntry, order_by: [desc: w.inserted_at]))
  end

  @doc """
  Gets a single waitlist entry.
  """
  def get_waitlist_entry!(id), do: Repo.get!(WaitlistEntry, id)

  @doc """
  Gets a waitlist entry by email.
  """
  def get_waitlist_entry_by_email(email) do
    Repo.get_by(WaitlistEntry, email: email)
  end

  @doc """
  Creates a waitlist entry.
  """
  def create_waitlist_entry(attrs \\ %{}) do
    %WaitlistEntry{}
    |> WaitlistEntry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a waitlist entry.
  """
  def update_waitlist_entry(%WaitlistEntry{} = waitlist_entry, attrs) do
    waitlist_entry
    |> WaitlistEntry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a waitlist entry.
  """
  def delete_waitlist_entry(%WaitlistEntry{} = waitlist_entry) do
    Repo.delete(waitlist_entry)
  end

  @doc """
  Marks a waitlist entry as notified.
  """
  def mark_as_notified(%WaitlistEntry{} = waitlist_entry) do
    update_waitlist_entry(waitlist_entry, %{notified_at: DateTime.utc_now()})
  end

  @doc """
  Marks a waitlist entry as converted (when they sign up).
  """
  def mark_as_converted(%WaitlistEntry{} = waitlist_entry) do
    update_waitlist_entry(waitlist_entry, %{converted_at: DateTime.utc_now()})
  end

  @doc """
  Gets the count of waitlist entries.
  """
  def count_waitlist_entries do
    Repo.aggregate(WaitlistEntry, :count, :id)
  end
end
