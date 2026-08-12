require "test_helper"

## Verifies role-aware ActiveAdmin routing and privileged tool isolation.
class AuthenticationRedirectsTest < ActionDispatch::IntegrationTest
  ## Keeps authentication journey checks independent from unrelated database fixtures.
  self.fixture_table_names = []

  ## Creates isolated normal and designated administrative users for each test.
  setup do
    host! "localhost"
    @password = "integration-password"
    @normal_user = User.create!(
      email: "routing-normal@example.test",
      password: @password,
      password_confirmation: @password,
      admin: false
    )
    @admin_user = User.create!(
      email: "admin@example.com",
      password: @password,
      password_confirmation: @password,
      admin: true
    )
  end

  ## Verifies that anonymous visitors enter the user sign-in flow through ActiveAdmin.
  test "anonymous root request enters user sign in through active admin" do
    get root_path
    assert_redirected_to admin_root_path

    follow_redirect!
    assert_redirected_to new_user_session_path

    get "/sidekiq"
    assert_redirected_to "/users/sign_in"

    get "/sidekiq/"
    assert_redirected_to "/users/sign_in"
  end

  ## Verifies that normal users enter ActiveAdmin with exactly the allowed navigation links.
  test "normal user sees dashboard jobs and tags only" do
    sign_in_through_form(@normal_user)

    get admin_root_path
    assert_response :success
    assert_includes response.body, admin_dashboard_path
    assert_includes response.body, admin_jobs_path
    assert_includes response.body, admin_tags_path
    assert_not_includes response.body, admin_proposals_path
    assert_not_includes response.body, admin_oauth_credentials_path
    assert_includes response.body, "/sidekiq"
    assert_includes response.body, destroy_user_session_path
  end

  ## Verifies that direct privileged routes remain unavailable to a normal user.
  test "normal user cannot access proposals or oauth credentials but can access sidekiq" do
    sign_in_through_form(@normal_user)

    get admin_proposals_path
    assert_redirected_to admin_root_path

    get admin_oauth_credentials_path
    assert_redirected_to admin_root_path

    get "/sidekiq"
    assert_response :success

    get "/sidekiq/"
    assert_response :success
  end

  ## Verifies that the designated admin retains privileged navigation and route access.
  test "designated admin can access oauth credentials and sidekiq" do
    sign_in_through_form(@admin_user)

    get admin_root_path
    assert_response :success
    assert_includes response.body, admin_proposals_path
    assert_includes response.body, admin_oauth_credentials_path
    assert_includes response.body, "/sidekiq"
    assert_includes response.body, destroy_user_session_path
    assert_not_includes response.body, destroy_admin_user_session_path

    get admin_proposals_path
    assert_response :success

    get admin_oauth_credentials_path
    assert_response :success

    get "/sidekiq"
    assert_response :success

    get "/sidekiq/"
    assert_response :success
  end

  private

  # Authenticates an application user through the public Devise session endpoint.
  #
  # Parameters:
  # - user: The User whose credentials establish the browser session under test.
  #
  # Returns:
  # - The redirect response produced by a successful Devise login.
  #
  # Errors:
  # - Test assertions fail when Devise does not accept the supplied credentials.
  #
  # Notes:
  # - Uses the same session boundary as the production browser login flow.
  def sign_in_through_form(user)
    post user_session_path, params: {
      user: { email: user.email, password: @password }
    }

    assert_redirected_to root_path
  end
end
