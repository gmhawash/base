class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :username
      t.string :email
      t.string :password
      t.string :role
      t.boolean :active
      t.string :activation_code
      t.date :activation_code_generated
      t.timestamp :last_login
      t.string :password_salt

      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
