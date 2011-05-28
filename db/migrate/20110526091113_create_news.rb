class CreateNews < ActiveRecord::Migration
  def self.up
    create_table :news do |t|
      t.integer :user_id
      t.string :action
      t.integer :target_event_id

      t.timestamps
    end

    add_index :news, :user_id
    add_index :news, :action
    add_index :news, :target_event_id
  end

  def self.down
    drop_table :news
  end
end
