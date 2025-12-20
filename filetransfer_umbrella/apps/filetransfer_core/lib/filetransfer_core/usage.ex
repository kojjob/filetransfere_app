defmodule FiletransferCore.Usage do
  @moduledoc """
  The Usage context for managing usage statistics.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Usage.UsageStat
  alias FiletransferCore.Accounts.User
  alias FiletransferCore.Transfers.Transfer

  @doc """
  Gets usage statistics for a user.

  Returns a map with:
    * `:total_transfers` - Total number of transfers
    * `:total_bytes` - Total bytes transferred
    * `:monthly_usage` - Usage for current month
    * `:monthly_limit` - User's monthly limit
    * `:usage_percentage` - Percentage of limit used
  """
  def get_user_stats(user_id) do
    user = Repo.get(User, user_id)

    if user do
      current_month = Date.utc_today().month
      current_year = Date.utc_today().year

      monthly_stat =
        Repo.get_by(UsageStat,
          user_id: user_id,
          month: current_month,
          year: current_year
        )

      total_transfers =
        Transfer
        |> where([t], t.user_id == ^user_id)
        |> Repo.aggregate(:count)

      total_bytes =
        Transfer
        |> where([t], t.user_id == ^user_id and t.status == "completed")
        |> Repo.aggregate(:sum, :file_size) || 0

      monthly_bytes = if monthly_stat, do: monthly_stat.bytes_transferred, else: 0

      usage_percentage =
        if user.monthly_transfer_limit > 0 do
          Float.round(monthly_bytes / user.monthly_transfer_limit * 100, 1)
        else
          0.0
        end

      {:ok,
       %{
         total_transfers: total_transfers,
         total_bytes: total_bytes,
         monthly_usage: monthly_bytes,
         monthly_limit: user.monthly_transfer_limit,
         usage_percentage: usage_percentage,
         files_this_month: if(monthly_stat, do: monthly_stat.files_transferred, else: 0),
         api_calls_this_month: if(monthly_stat, do: monthly_stat.api_calls, else: 0)
       }}
    else
      {:error, :user_not_found}
    end
  end

  @doc """
  Gets platform-wide metrics for analytics dashboard.

  ## Options
    * `time_range` - Time range for metrics ("24h", "7d", "30d", "90d", "all")

  Returns a map with:
    * `:total_users` - Total number of users
    * `:active_users` - Number of active users
    * `:total_transfers` - Total number of transfers
    * `:total_bytes` - Total bytes transferred
    * `:transfers_by_status` - Breakdown by status
    * `:user_growth` - Recent user signups
  """
  def get_platform_metrics(time_range \\ "30d") do
    start_date = calculate_start_date(time_range)

    total_users = Repo.aggregate(User, :count)

    active_users =
      User
      |> where([u], u.is_active == true)
      |> Repo.aggregate(:count)

    total_transfers =
      Transfer
      |> maybe_filter_by_date(start_date)
      |> Repo.aggregate(:count)

    total_bytes =
      Transfer
      |> where([t], t.status == "completed")
      |> maybe_filter_by_date(start_date)
      |> Repo.aggregate(:sum, :file_size) || 0

    transfers_by_status =
      Transfer
      |> maybe_filter_by_date(start_date)
      |> group_by([t], t.status)
      |> select([t], {t.status, count(t.id)})
      |> Repo.all()
      |> Enum.into(%{})

    user_growth =
      User
      |> maybe_filter_by_date(start_date)
      |> group_by([u], fragment("DATE(inserted_at)"))
      |> select([u], {fragment("DATE(inserted_at)"), count(u.id)})
      |> order_by([u], asc: fragment("DATE(inserted_at)"))
      |> Repo.all()
      |> Enum.map(fn {date, count} -> %{date: date, count: count} end)

    users_by_tier =
      User
      |> group_by([u], u.subscription_tier)
      |> select([u], {u.subscription_tier, count(u.id)})
      |> Repo.all()
      |> Enum.into(%{})

    users_by_role =
      User
      |> group_by([u], u.role)
      |> select([u], {u.role, count(u.id)})
      |> Repo.all()
      |> Enum.into(%{})

    {:ok,
     %{
       total_users: total_users,
       active_users: active_users,
       total_transfers: total_transfers,
       total_bytes: total_bytes,
       transfers_by_status: transfers_by_status,
       user_growth: user_growth,
       users_by_tier: users_by_tier,
       users_by_role: users_by_role,
       time_range: time_range
     }}
  end

  @doc """
  Records usage for a transfer.
  """
  def record_transfer_usage(user_id, bytes) do
    current_month = Date.utc_today().month
    current_year = Date.utc_today().year

    case Repo.get_by(UsageStat, user_id: user_id, month: current_month, year: current_year) do
      nil ->
        %UsageStat{}
        |> UsageStat.changeset(%{
          user_id: user_id,
          month: current_month,
          year: current_year,
          bytes_transferred: bytes,
          files_transferred: 1
        })
        |> Repo.insert()

      stat ->
        stat
        |> UsageStat.changeset(%{
          bytes_transferred: stat.bytes_transferred + bytes,
          files_transferred: stat.files_transferred + 1
        })
        |> Repo.update()
    end
  end

  @doc """
  Records an API call for a user.
  """
  def record_api_call(user_id) do
    current_month = Date.utc_today().month
    current_year = Date.utc_today().year

    case Repo.get_by(UsageStat, user_id: user_id, month: current_month, year: current_year) do
      nil ->
        %UsageStat{}
        |> UsageStat.changeset(%{
          user_id: user_id,
          month: current_month,
          year: current_year,
          api_calls: 1
        })
        |> Repo.insert()

      stat ->
        stat
        |> UsageStat.changeset(%{api_calls: stat.api_calls + 1})
        |> Repo.update()
    end
  end

  @doc """
  Gets usage history for a user over the past N months.
  """
  def get_user_usage_history(user_id, months \\ 12) do
    UsageStat
    |> where([s], s.user_id == ^user_id)
    |> order_by([s], desc: s.year, desc: s.month)
    |> limit(^months)
    |> Repo.all()
  end

  # Private helpers

  defp calculate_start_date("24h"), do: DateTime.add(DateTime.utc_now(), -1, :day)
  defp calculate_start_date("7d"), do: DateTime.add(DateTime.utc_now(), -7, :day)
  defp calculate_start_date("30d"), do: DateTime.add(DateTime.utc_now(), -30, :day)
  defp calculate_start_date("90d"), do: DateTime.add(DateTime.utc_now(), -90, :day)
  defp calculate_start_date("all"), do: nil
  defp calculate_start_date(_), do: DateTime.add(DateTime.utc_now(), -30, :day)

  defp maybe_filter_by_date(query, nil), do: query

  defp maybe_filter_by_date(query, start_date) do
    from(q in query, where: q.inserted_at >= ^start_date)
  end
end
