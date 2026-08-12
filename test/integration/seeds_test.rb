require "test_helper"

## Verifies that configured seed credentials are reconciled without duplicating accounts.
class SeedsTest < ActiveSupport::TestCase
  ## Keeps seed reconciliation checks independent from unrelated database fixtures.
  self.fixture_table_names = []

  ## Verifies that repeated seed runs restore passwords and preserve intended account roles.
  test "seeds reconcile existing authentication accounts" do
    seed_environment = {
      "ADMIN_SEED_EMAIL" => "seed-admin@example.test",
      "ADMIN_SEED_PASSWORD" => "new-admin-password",
      "NORMAL_SEED_EMAIL" => "seed-normal@example.test",
      "NORMAL_SEED_PASSWORD" => "new-normal-password"
    }
    previous_environment = seed_environment.keys.to_h { |key| [ key, ENV[key] ] }
    seed_environment.each { |key, value| ENV[key] = value }

    admin_user = AdminUser.create!(
      email: seed_environment.fetch("ADMIN_SEED_EMAIL"),
      password: "stale-admin-password",
      password_confirmation: "stale-admin-password"
    )
    application_admin = User.create!(
      email: seed_environment.fetch("ADMIN_SEED_EMAIL"),
      password: "stale-admin-password",
      password_confirmation: "stale-admin-password",
      admin: false
    )
    normal_user = User.create!(
      email: seed_environment.fetch("NORMAL_SEED_EMAIL"),
      password: "stale-normal-password",
      password_confirmation: "stale-normal-password",
      admin: true
    )

    load Rails.root.join("db/seeds.rb")

    assert admin_user.reload.valid_password?(seed_environment.fetch("ADMIN_SEED_PASSWORD"))
    assert application_admin.reload.valid_password?(seed_environment.fetch("ADMIN_SEED_PASSWORD"))
    assert_predicate application_admin, :admin?
    assert normal_user.reload.valid_password?(seed_environment.fetch("NORMAL_SEED_PASSWORD"))
    assert_not_predicate normal_user, :admin?

    account_counts = [ AdminUser.count, User.count ]
    load Rails.root.join("db/seeds.rb")
    assert_equal account_counts, [ AdminUser.count, User.count ]
  ensure
    previous_environment&.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
