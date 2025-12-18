defmodule FiletransferCore.Waitlist do
  @moduledoc """
  The Waitlist context for managing waitlist entries.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Waitlist.WaitlistEntry

  @doc """
  Returns the list of waitlist entries, ordered by newest first.
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
    waitlist_entry
    |> WaitlistEntry.status_changeset(%{notified_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Marks a waitlist entry as converted (when they sign up).
  """
  def mark_as_converted(%WaitlistEntry{} = waitlist_entry) do
    waitlist_entry
    |> WaitlistEntry.status_changeset(%{converted_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Gets the count of waitlist entries.
  """
  def count_waitlist_entries do
    Repo.aggregate(WaitlistEntry, :count, :id)
  end

  # ============================================================================
  # Analytics & Dashboard Functions
  # ============================================================================

  @doc """
  Counts entries created within a date range.
  Used for calculating growth rates.
  """
  def count_entries_in_range(start_datetime, end_datetime) do
    from(w in WaitlistEntry,
      where: w.inserted_at >= ^start_datetime and w.inserted_at <= ^end_datetime
    )
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Searches entries by email, name, or use_case.
  Case-insensitive search using ILIKE.
  """
  def search_entries(nil), do: list_waitlist_entries()
  def search_entries(""), do: list_waitlist_entries()

  def search_entries(query) when is_binary(query) do
    search_term = "%#{query}%"

    from(w in WaitlistEntry,
      where:
        ilike(w.email, ^search_term) or
          ilike(coalesce(w.name, ""), ^search_term) or
          ilike(coalesce(w.use_case, ""), ^search_term),
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Filters entries by status.
  - "pending" - not notified, not converted
  - "notified" - notified but not converted
  - "converted" - converted (regardless of notified status)
  - "all" or nil - all entries
  """
  def filter_by_status("pending") do
    from(w in WaitlistEntry,
      where: is_nil(w.notified_at) and is_nil(w.converted_at),
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  def filter_by_status("notified") do
    from(w in WaitlistEntry,
      where: not is_nil(w.notified_at) and is_nil(w.converted_at),
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  def filter_by_status("converted") do
    from(w in WaitlistEntry,
      where: not is_nil(w.converted_at),
      order_by: [desc: w.inserted_at]
    )
    |> Repo.all()
  end

  def filter_by_status(_), do: list_waitlist_entries()

  @doc """
  Returns daily signup counts for the last N days.
  Used for rendering trend charts/sparklines.
  Returns a list of {date, count} tuples ordered by date ascending.
  """
  def daily_signups(days) when is_integer(days) and days > 0 do
    today = Date.utc_today()
    start_date = Date.add(today, -(days - 1))

    # Get counts grouped by date
    counts_by_date =
      from(w in WaitlistEntry,
        where: fragment("?::date", w.inserted_at) >= ^start_date,
        group_by: fragment("?::date", w.inserted_at),
        select: {fragment("?::date", w.inserted_at), count(w.id)}
      )
      |> Repo.all()
      |> Map.new()

    # Generate all dates in range and fill in zeros
    Date.range(start_date, today)
    |> Enum.map(fn date ->
      {date, Map.get(counts_by_date, date, 0)}
    end)
  end

  @doc """
  Returns a breakdown of entries by status.
  Returns a map with :pending, :notified, :converted, :total counts.
  """
  def status_breakdown do
    entries = list_waitlist_entries()

    pending_count =
      Enum.count(entries, fn e -> is_nil(e.notified_at) and is_nil(e.converted_at) end)

    notified_count =
      Enum.count(entries, fn e -> not is_nil(e.notified_at) and is_nil(e.converted_at) end)

    converted_count = Enum.count(entries, fn e -> not is_nil(e.converted_at) end)

    %{
      pending: pending_count,
      notified: notified_count,
      converted: converted_count,
      total: length(entries)
    }
  end

  @doc """
  Calculates week-over-week growth rate as a percentage.
  Returns 100.0 if previous week had zero entries (infinite growth).
  Returns 0.0 if current week also has zero entries.
  """
  def growth_rate do
    now = DateTime.utc_now()
    week_ago = DateTime.add(now, -7, :day)
    two_weeks_ago = DateTime.add(now, -14, :day)

    this_week_count = count_entries_in_range(week_ago, now)
    last_week_count = count_entries_in_range(two_weeks_ago, week_ago)

    cond do
      last_week_count == 0 and this_week_count == 0 -> 0.0
      last_week_count == 0 -> 100.0
      true -> Float.round((this_week_count - last_week_count) / last_week_count * 100, 1)
    end
  end
end


