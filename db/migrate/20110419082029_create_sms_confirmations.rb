class CreateSmsConfirmations < ActiveRecord::Migration
  def self.up
    create_table :sms_confirmations do |t|
      t.integer :user_id
      t.string :token
      t.boolean :confirmed

      t.timestamps
    end

    add_index :sms_confirmations, :user_id
  end

  def self.down
    drop_table :sms_confirmations
  end
end
