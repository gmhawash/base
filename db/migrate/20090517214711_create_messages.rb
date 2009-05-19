class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.integer :project_id
      t.integer :sender_id
      t.integer :recepient_id
      t.date :read_on

      t.timestamps
    end
  end

  def self.down
    drop_table :messages
  end
end
