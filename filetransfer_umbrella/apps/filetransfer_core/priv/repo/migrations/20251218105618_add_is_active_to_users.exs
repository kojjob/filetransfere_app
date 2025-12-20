defmodule FiletransferCore.Repo.Migrations.AddIsActiveToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_active, :boolean, default: true, null: false
    end

    create index(:users, [:is_active])
  end
end
