# class ApplicationController < ActionController::Base
#   # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
#   allow_browser versions: :modern
# end
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def authenticate_admin_user!
    # Check if the current user is signed in and is an admin
    if user_signed_in? && current_user.admin? # Replace with your actual admin check
      true
    else
      sign_out(current_user)
      redirect_to new_user_session_path, alert: "You must be an admin to access this section."
    end
  end

  # Optionally define current_admin_user method
  def current_admin_user
    current_user # or however you determine the current admin user
  end

  private

  def admin_namespace?
    request.fullpath.start_with?('/admin')
  end
end
