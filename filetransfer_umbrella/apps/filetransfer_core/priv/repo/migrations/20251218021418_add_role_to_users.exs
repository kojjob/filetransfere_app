defmodule FiletransferCore.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string, null: false, default: "user"
    end

    # Create index for efficient role-based queries
    create index(:users, [:role])
  end
end
