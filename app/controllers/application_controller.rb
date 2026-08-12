## Provides shared authentication behavior for application and ActiveAdmin controllers.
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
end
