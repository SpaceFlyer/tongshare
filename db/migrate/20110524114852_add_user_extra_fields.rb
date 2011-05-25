class AddUserExtraFields < ActiveRecord::Migration
  def self.up
    add_column :user_extras, :gender, :string
    add_column :user_extras, :city, :string
    add_column :user_extras, :org, :string
    add_column :user_extras, :homepage, :string
    add_column :user_extras, :qq, :string
    add_column :user_extras, :fetion, :string
    add_column :user_extras, :msn, :string
    add_column :user_extras, :gtalk, :string
    add_index :user_extras, :gender
    add_index :user_extras, :city
    add_index :user_extras, :org
    add_index :user_extras, :homepage
    add_index :user_extras, :qq
    add_index :user_extras, :fetion
    add_index :user_extras, :msn
    add_index :user_extras, :gtalk
  end

  def self.down
    remove_column :user_extras, :gender, :string
    remove_column :user_extras, :city, :string
    remove_column :user_extras, :org, :string
    remove_column :user_extras, :homepage, :string
    remove_column :user_extras, :qq, :string
    remove_column :user_extras, :fetion, :string
    remove_column :user_extras, :msn, :string
    remove_column :user_extras, :gtalk, :string
  end
end
