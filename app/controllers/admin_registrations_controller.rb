class AdminRegistrationsController < Devise::RegistrationsController
  before_action :authenticate_user!, only: [:new, :create]

  def new
    super
  end

  def create
    super
  end

  protected

  # Redirect to Active Admin after sign-up
  def after_sign_up_path_for(resource)
    admin_root_path
  end
end
