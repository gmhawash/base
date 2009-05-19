class CreateRatings < ActiveRecord::Migration
  def self.up
    create_table :ratings do |t|
      t.integer :project_id
      t.integer :contractor_id
      t.string :service_id
      t.date :start_date
      t.string :response

      t.timestamps
    end
  end

  def self.down
    drop_table :ratings
  end
end
