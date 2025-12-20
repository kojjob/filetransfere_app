defmodule FiletransferCore.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias FiletransferCore.Repo
  alias FiletransferCore.Accounts.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Returns the list of users with filtering options.

  ## Options
    * `:search` - Search by email or name
    * `:role` - Filter by role ("user", "project_owner")
    * `:status` - Filter by active status ("active", "inactive")
    * `:sort_by` - Sort field (:inserted_at, :email, :name)
    * `:sort_order` - Sort direction (:asc, :desc)
    * `:limit` - Limit number of results
    * `:offset` - Offset for pagination
  """
  def list_users(opts) do
    search = Keyword.get(opts, :search, "")
    role = Keyword.get(opts, :role)
    status = Keyword.get(opts, :status)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_order = Keyword.get(opts, :sort_order, :desc)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset)

    query = from(u in User)

    query =
      if search != "" do
        search_term = "%#{search}%"
        from(u in query, where: ilike(u.email, ^search_term) or ilike(u.name, ^search_term))
      else
        query
      end

    query =
      if role && role != "" do
        from(u in query, where: u.role == ^role)
      else
        query
      end

    query =
      if status && status != "" do
        case status do
          "active" -> from(u in query, where: u.is_active == true)
          "inactive" -> from(u in query, where: u.is_active == false)
          _ -> query
        end
      else
        query
      end

    query =
      case {sort_by, sort_order} do
        {:inserted_at, :asc} -> from(u in query, order_by: [asc: u.inserted_at])
        {:inserted_at, :desc} -> from(u in query, order_by: [desc: u.inserted_at])
        {:email, :asc} -> from(u in query, order_by: [asc: u.email])
        {:email, :desc} -> from(u in query, order_by: [desc: u.email])
        {:name, :asc} -> from(u in query, order_by: [asc: u.name])
        {:name, :desc} -> from(u in query, order_by: [desc: u.name])
        _ -> from(u in query, order_by: [desc: u.inserted_at])
      end

    query =
      if limit do
        from(u in query, limit: ^limit)
      else
        query
      end

    query =
      if offset do
        from(u in query, offset: ^offset)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Gets a single user. Raises if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user. Returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.verify_password(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        {:error, :not_found}
    end
  end

  @doc """
  Confirms a user's email.
  """
  def confirm_user(%User{} = user) do
    update_user(user, %{confirmed_at: NaiveDateTime.utc_now()})
  end

  @doc """
  Updates user subscription tier and limits.
  """
  def update_subscription(user, tier) do
    limits = subscription_limits(tier)

    update_user(user, Map.merge(%{subscription_tier: tier}, limits))
  end

  defp subscription_limits("free") do
    %{
      # 5GB
      monthly_transfer_limit: 5_368_709_120,
      # 2GB
      max_file_size: 2_147_483_648,
      api_calls_limit: 0
    }
  end

  defp subscription_limits("pro") do
    %{
      # 100GB
      monthly_transfer_limit: 107_374_182_400,
      # 10GB
      max_file_size: 10_737_418_240,
      api_calls_limit: 1_000
    }
  end

  defp subscription_limits("business") do
    %{
      # 500GB
      monthly_transfer_limit: 536_870_912_000,
      # 50GB
      max_file_size: 53_687_091_200,
      api_calls_limit: :unlimited
    }
  end

  defp subscription_limits("enterprise") do
    %{
      monthly_transfer_limit: :unlimited,
      max_file_size: :unlimited,
      api_calls_limit: :unlimited
    }
  end

  # Role Management Functions

  @doc """
  Checks if a user is a project owner.
  """
  def project_owner?(%User{} = user), do: User.project_owner?(user)
  def project_owner?(_), do: false

  @doc """
  Promotes a user to project owner role.
  """
  def promote_to_project_owner(%User{} = user) do
    user
    |> User.role_changeset(%{role: "project_owner"})
    |> Repo.update()
  end

  @doc """
  Demotes a user to regular user role.
  """
  def demote_to_user(%User{} = user) do
    user
    |> User.role_changeset(%{role: "user"})
    |> Repo.update()
  end

  @doc """
  Updates a user's role.
  """
  def update_user_role(%User{} = user, role) when role in ["user", "project_owner"] do
    user
    |> User.role_changeset(%{role: role})
    |> Repo.update()
  end

  @doc """
  Lists all project owners.
  """
  def list_project_owners do
    User
    |> where([u], u.role == "project_owner")
    |> Repo.all()
  end

  @doc """
  Lists all regular users (non-project-owners).
  """
  def list_regular_users do
    User
    |> where([u], u.role == "user")
    |> Repo.all()
  end

  @doc """
  Counts users by role.
  """
  def count_users_by_role do
    User
    |> group_by([u], u.role)
    |> select([u], {u.role, count(u.id)})
    |> Repo.all()
    |> Enum.into(%{})
  end

  # User Status Management Functions

  @doc """
  Toggles a user's active status.
  """
  def toggle_user_status(%User{} = user) do
    user
    |> User.status_changeset(%{is_active: !user.is_active})
    |> Repo.update()
  end

  @doc """
  Activates a user.
  """
  def activate_user(%User{} = user) do
    user
    |> User.status_changeset(%{is_active: true})
    |> Repo.update()
  end

  @doc """
  Deactivates a user.
  """
  def deactivate_user(%User{} = user) do
    user
    |> User.status_changeset(%{is_active: false})
    |> Repo.update()
  end

  @doc """
  Counts total users.
  """
  def count_users do
    Repo.aggregate(User, :count)
  end

  @doc """
  Counts active users.
  """
  def count_active_users do
    User
    |> where([u], u.is_active == true)
    |> Repo.aggregate(:count)
  end
end
