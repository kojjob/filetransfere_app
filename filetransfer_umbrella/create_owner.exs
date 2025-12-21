# Create a project owner user for testing
alias FiletransferCore.Accounts

# First, try to find existing owner
case Accounts.get_user_by_email("owner@example.com") do
  nil ->
    # Create new owner
    {:ok, user} = Accounts.create_user(%{
      email: "owner@example.com",
      password: "Password123!",
      name: "Test Owner",
      subscription_tier: "enterprise"
    })
    # Update role to project_owner
    {:ok, user} = Accounts.update_user_role(user, "project_owner")
    IO.puts("✓ Created project owner: owner@example.com / Password123!")

  user ->
    # Update existing to ensure project_owner role
    {:ok, user} = Accounts.update_user_role(user, "project_owner")
    IO.puts("✓ Updated existing user to project_owner: owner@example.com / Password123!")
end
