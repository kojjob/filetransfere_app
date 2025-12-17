defmodule FiletransferWeb.Mailer do
  @moduledoc """
  Mailer module for sending emails via Swoosh.

  Uses Resend adapter in production for reliable email delivery.
  """
  use Swoosh.Mailer, otp_app: :filetransfer_web
end
