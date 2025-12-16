defmodule FiletransferCore.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :name, :string
      add :hashed_password, :string, null: false
      add :subscription_tier, :string, default: "free", null: false
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :monthly_transfer_limit, :bigint, default: 5_368_709_120, null: false # 5GB in bytes
      add :max_file_size, :bigint, default: 2_147_483_648, null: false # 2GB in bytes
      add :api_calls_limit, :integer, default: 0
      add :api_calls_used, :integer, default: 0
      add :confirmed_at, :naive_datetime
      add :reset_password_token, :string
      add :reset_password_sent_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create index(:users, [:stripe_customer_id])
    create index(:users, [:subscription_tier])
  end
end
