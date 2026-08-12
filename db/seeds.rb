# This file should ensure the existence of records required to run the application in every
# environment (production, development, test). It should be idempotent so it can be executed
# at any point in any environment.
#
# Load seeds with:
#   bin/rails db:seed
#
# In production, credentials must be provided by env vars so no weak hardcoded password is used.
admin_email = ENV.fetch("ADMIN_SEED_EMAIL", "admin@example.com")
admin_password = ENV["ADMIN_SEED_PASSWORD"]
normal_email = ENV["NORMAL_SEED_EMAIL"]
normal_password = ENV["NORMAL_SEED_PASSWORD"]

if Rails.env.production? && admin_password.blank?
  warn(
    "Skipping admin seed in production: set ADMIN_SEED_EMAIL (optional) and ADMIN_SEED_PASSWORD in env."
  )
else
  seed_password = admin_password || "password"

  # Seed ActiveAdmin user used by ActiveAdmin Devise routes (if admin features are used).
  AdminUser.find_or_initialize_by(email: admin_email).tap do |admin_user|
    admin_user.password = seed_password
    admin_user.password_confirmation = seed_password
    admin_user.save!
    puts "Reconciled AdminUser: #{admin_user.email}"
  end

  # Seed application-level admin user used by custom admin checks (current_user.admin?).
  User.find_or_initialize_by(email: admin_email).tap do |user|
    user.password = seed_password
    user.password_confirmation = seed_password
    user.admin = true
    user.save!
    puts "Reconciled User: #{user.email}"
  end
end

if normal_email.present?
  if Rails.env.production? && normal_password.blank?
    warn(
      "Skipping normal seed in production: set NORMAL_SEED_EMAIL and NORMAL_SEED_PASSWORD in env."
    )
  else
    seed_password = normal_password || "password"

    # Seed a normal application user for non-admin use.
    User.find_or_initialize_by(email: normal_email).tap do |user|
      user.password = seed_password
      user.password_confirmation = seed_password
      user.admin = false
      user.save!
      puts "Reconciled normal User: #{user.email}"
    end
  end
end
