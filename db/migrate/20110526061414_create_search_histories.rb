class CreateSearchHistories < ActiveRecord::Migration
  def self.up
    create_table :search_histories do |t|
      t.text :param
      t.integer :user_id

      t.timestamps
    end

    add_index :search_histories, :user_id
  end

  def self.down
    drop_table :search_histories
  end
end
