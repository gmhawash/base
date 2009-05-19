# == Schema Information
#
# Table name: users
#
#  id                        :integer         not null, primary key
#  username                  :string(255)
#  email                     :string(255)
#  password                  :string(255)
#  role                      :string(255)
#  active                    :boolean
#  activation_code           :string(255)
#  activation_code_generated :date
#  last_login                :datetime
#  password_salt             :string(255)
#  created_at                :datetime
#  updated_at                :datetime
#

class User < ActiveRecord::Base
  def admin?
    role =~ /admin/
  end
  
end
