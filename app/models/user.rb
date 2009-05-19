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
  attr_accessor :reset_password, :password_confirmation

  validates_uniqueness_of :email
  validates_presence_of :email, :name, :password
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :message => "should look like user@example.com"
  validates_confirmation_of :password

  def name_and_email
    name + ' <' + email + '>'
  end

  def generate_activation_code
    self.activation_code_generated = Date.today
    self.activation_code = random_string
  end
  
  def password_confirmation=(p)
    @password_confirmation = hash_password(p) unless p.blank?
  end
    
  def password=(p)
    super(hash_password(p)) unless p.blank?
  end
  
  
  def random_string
    Digest::SHA1.hexdigest(rand().to_s + rand().to_s + rand().to_s) 
  end
  
  def hashed_password(p)
    Digest::SHA1.hexdigest("#{password_salt}--#{p}--")
  end
  
  private
  
  def hash_password(p)
    @salt ||= random_string
    self.password_salt = @salt
    hashed_password(p)
  end

  def self.authenticate(email, password)
    u = find(:first, :conditions => { :active => true, :email => email })
    if !u.nil? && u.hashed_password(password) == u.password
      return u
    else
      return nil
    end
  end

  
  def admin?
    role =~ /admin/
  end
  
end
