class AddNameToRemovedEvent < ActiveRecord::Migration
  def self.up
    add_column :removed_events, :name, :string
  end

  def self.down
    remove_column :removed_events, :name
  end
end
