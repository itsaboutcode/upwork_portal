require "test_helper"

## Verifies that authentication configuration is safe to eager load and exposes no signup flow.
class AuthenticationConfigurationTest < ActiveSupport::TestCase
  ## Keeps authentication configuration checks independent from unrelated database fixtures.
  self.fixture_table_names = []

  ## Verifies that every application constant satisfies Rails autoloading conventions.
  test "application eager loads without Zeitwerk errors" do
    assert_nothing_raised { Rails.autoloaders.main.eager_load }
  end

  ## Verifies that normal and administrative accounts cannot self-register.
  test "registration is disabled for every account type" do
    assert_not_includes User.devise_modules, :registerable
    assert_not_includes AdminUser.devise_modules, :registerable

    route_helpers = Rails.application.routes.url_helpers
    assert_not_respond_to route_helpers, :new_user_registration_path
    assert_not_respond_to route_helpers, :new_admin_user_registration_path
  end
end
