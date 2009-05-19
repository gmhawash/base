class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :name
      t.string :email,          :null => false
      t.string :password,       :null => false
      t.string :role
      t.boolean :active,                           :default => false
      t.string :activation_code
      t.date :activation_code_generated
      t.timestamp :last_login
      t.string :password_salt

      t.timestamps
    end
    
    add_index :users, :email, :unique => true
    
    user = User.new :name => 'admin', :email => 'admin@website.xyz', :role => 'admin', :active => true, :password_salt => 'Wh@t1zit', :password => 'maher'
    user.save!
  end

  def self.down
    drop_table :users
  end
end
