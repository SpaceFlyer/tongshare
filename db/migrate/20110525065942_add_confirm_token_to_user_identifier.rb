class AddConfirmTokenToUserIdentifier < ActiveRecord::Migration
  def self.up
    add_column :user_identifiers, :confirm_token, :string
  end

  def self.down
    remove_column :user_identifiers, :confirm_token
  end
end
