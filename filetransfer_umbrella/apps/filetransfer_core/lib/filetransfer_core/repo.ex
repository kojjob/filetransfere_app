defmodule FiletransferCore.Repo do
  use Ecto.Repo,
    otp_app: :filetransfer_core,
    adapter: Ecto.Adapters.Postgres
end


