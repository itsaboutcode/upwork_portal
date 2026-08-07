class PwaController < ApplicationController
  skip_before_action :authenticate_user!

  def manifest
    # The file will automatically be rendered as manifest.json
  end
end
