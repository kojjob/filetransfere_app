defmodule FiletransferCore.AccountsTest do
  use FiletransferCore.DataCase, async: true

  alias FiletransferCore.Accounts
  alias FiletransferCore.Accounts.User

  describe "user creation" do
    test "create_user/1 with valid data creates a user with default role" do
      unique_email = "test_#{unique_suffix()}@example.com"

      attrs = %{
        email: unique_email,
        name: "Test User",
        password: "Password123!"
      }

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.email == unique_email
      assert user.name == "Test User"
      assert user.role == "user"
    end

    test "create_user/1 with invalid data returns error changeset" do
      attrs = %{email: "invalid", password: "short"}

      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(attrs)
    end
  end

  describe "project_owner?/1" do
    test "returns true for user with project_owner role" do
      {:ok, user} = create_user()
      {:ok, project_owner} = Accounts.promote_to_project_owner(user)

      assert Accounts.project_owner?(project_owner) == true
    end

    test "returns false for user with regular user role" do
      {:ok, user} = create_user()

      assert Accounts.project_owner?(user) == false
    end

    test "returns false for nil" do
      assert Accounts.project_owner?(nil) == false
    end

    test "returns false for non-user values" do
      assert Accounts.project_owner?("not a user") == false
      assert Accounts.project_owner?(%{role: "project_owner"}) == false
    end
  end

  describe "promote_to_project_owner/1" do
    test "changes user role to project_owner" do
      {:ok, user} = create_user()
      assert user.role == "user"

      {:ok, promoted} = Accounts.promote_to_project_owner(user)
      assert promoted.role == "project_owner"
    end

    test "is idempotent for already promoted users" do
      {:ok, user} = create_user()
      {:ok, promoted} = Accounts.promote_to_project_owner(user)
      {:ok, promoted_again} = Accounts.promote_to_project_owner(promoted)

      assert promoted_again.role == "project_owner"
    end

    test "persists the change to the database" do
      {:ok, user} = create_user()
      {:ok, _promoted} = Accounts.promote_to_project_owner(user)

      reloaded = Repo.get!(User, user.id)
      assert reloaded.role == "project_owner"
    end
  end

  describe "demote_to_user/1" do
    test "changes project_owner role to user" do
      {:ok, user} = create_user()
      {:ok, project_owner} = Accounts.promote_to_project_owner(user)
      assert project_owner.role == "project_owner"

      {:ok, demoted} = Accounts.demote_to_user(project_owner)
      assert demoted.role == "user"
    end

    test "is idempotent for regular users" do
      {:ok, user} = create_user()
      {:ok, demoted} = Accounts.demote_to_user(user)

      assert demoted.role == "user"
    end

    test "persists the change to the database" do
      {:ok, user} = create_user()
      {:ok, project_owner} = Accounts.promote_to_project_owner(user)
      {:ok, _demoted} = Accounts.demote_to_user(project_owner)

      reloaded = Repo.get!(User, user.id)
      assert reloaded.role == "user"
    end
  end

  describe "list_project_owners/0" do
    test "returns only users with project_owner role" do
      {:ok, user1} = create_user("owner1_#{unique_suffix()}@example.com")
      {:ok, user2} = create_user("owner2_#{unique_suffix()}@example.com")
      {:ok, user3} = create_user("regular_#{unique_suffix()}@example.com")

      {:ok, _owner1} = Accounts.promote_to_project_owner(user1)
      {:ok, _owner2} = Accounts.promote_to_project_owner(user2)
      # user3 remains regular user

      owners = Accounts.list_project_owners()
      owner_ids = Enum.map(owners, & &1.id)

      # Check that our promoted users are in the list
      assert user1.id in owner_ids
      assert user2.id in owner_ids
      # Check that regular user is NOT in the list
      refute user3.id in owner_ids
    end

    test "promoted user appears in list" do
      {:ok, user} = create_user()
      {:ok, promoted} = Accounts.promote_to_project_owner(user)

      owners = Accounts.list_project_owners()
      owner_ids = Enum.map(owners, & &1.id)

      assert promoted.id in owner_ids
    end
  end

  describe "list_regular_users/0" do
    test "returns only users with user role" do
      {:ok, user1} = create_user("owner_#{unique_suffix()}@example.com")
      {:ok, user2} = create_user("regular1_#{unique_suffix()}@example.com")
      {:ok, user3} = create_user("regular2_#{unique_suffix()}@example.com")

      {:ok, _owner} = Accounts.promote_to_project_owner(user1)
      # user2 and user3 remain regular users

      regular_users = Accounts.list_regular_users()
      user_ids = Enum.map(regular_users, & &1.id)

      # Check that promoted user is NOT in the regular users list
      refute user1.id in user_ids
      # Check that regular users ARE in the list
      assert user2.id in user_ids
      assert user3.id in user_ids
    end

    test "regular user appears in list" do
      {:ok, user} = create_user()

      regular_users = Accounts.list_regular_users()
      user_ids = Enum.map(regular_users, & &1.id)

      assert user.id in user_ids
    end
  end

  describe "count_users_by_role/0" do
    test "counts increase correctly when users are created and promoted" do
      # Get initial counts
      initial_counts = Accounts.count_users_by_role()
      initial_users = Map.get(initial_counts, "user", 0)
      initial_owners = Map.get(initial_counts, "project_owner", 0)

      # Create 3 regular users
      {:ok, user1} = create_user()
      {:ok, _user2} = create_user()
      {:ok, _user3} = create_user()

      # Promote one to project owner
      {:ok, _owner1} = Accounts.promote_to_project_owner(user1)

      # Get new counts
      new_counts = Accounts.count_users_by_role()

      # Should have 2 more regular users (3 created, 1 promoted away)
      assert Map.get(new_counts, "user", 0) == initial_users + 2
      # Should have 1 more project owner
      assert Map.get(new_counts, "project_owner", 0) == initial_owners + 1
    end

    test "returns a map with role counts" do
      {:ok, user} = create_user()
      {:ok, _owner} = Accounts.promote_to_project_owner(user)

      counts = Accounts.count_users_by_role()

      # Just verify the structure - counts should be integers
      assert is_map(counts)
      assert is_integer(Map.get(counts, "project_owner", 0))
    end
  end

  describe "User.role_changeset/2" do
    test "accepts valid roles" do
      {:ok, user} = create_user()

      changeset = User.role_changeset(user, %{role: "project_owner"})
      assert changeset.valid?

      changeset = User.role_changeset(user, %{role: "user"})
      assert changeset.valid?
    end

    test "rejects invalid roles" do
      {:ok, user} = create_user()

      changeset = User.role_changeset(user, %{role: "admin"})
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role

      changeset = User.role_changeset(user, %{role: "superuser"})
      refute changeset.valid?
    end

    test "requires role field" do
      {:ok, user} = create_user()

      changeset = User.role_changeset(user, %{role: nil})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end
  end

  describe "User.project_owner?/1" do
    test "returns true for project_owner role" do
      {:ok, user} = create_user()
      {:ok, project_owner} = Accounts.promote_to_project_owner(user)

      assert User.project_owner?(project_owner) == true
    end

    test "returns false for user role" do
      {:ok, user} = create_user()

      assert User.project_owner?(user) == false
    end

    test "returns false for nil" do
      assert User.project_owner?(nil) == false
    end
  end

  # Helper functions

  defp create_user(email \\ nil) do
    unique_id = :erlang.unique_integer([:positive, :monotonic])
    timestamp = System.system_time(:microsecond)

    attrs = %{
      email: email || "user#{unique_id}_#{timestamp}@example.com",
      name: "Test User",
      password: "Password123!"
    }

    Accounts.create_user(attrs)
  end

  defp unique_suffix do
    "#{:erlang.unique_integer([:positive, :monotonic])}_#{System.system_time(:microsecond)}"
  end
end
