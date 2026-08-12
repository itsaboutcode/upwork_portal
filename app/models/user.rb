## Authenticated application account with an explicit administrative role flag.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  def admin?
    self.admin # This should return true if the user is an admin
  end
end
