alias FiletransferCore.Sharing
alias FiletransferCore.Sharing.ShareLink
alias FiletransferCore.Storage

user_id = "user_123"
transfer_id = "transfer_456"
simple_name = "report.pdf"
complex_name = "Q4 Report (Final) #3!!.PDF"

share_link = %ShareLink{token: "test-token", password_hash: nil}

Benchee.run(
  %{
    "generate_key" => fn file_name ->
      Storage.generate_key(user_id, transfer_id, file_name)
    end,
    "share_url" => fn _file_name ->
      Sharing.share_url(share_link, "https://zipshare.test")
    end
  },
  inputs: %{
    "simple_name" => simple_name,
    "complex_name" => complex_name
  },
  time: 2,
  memory_time: 1
)
