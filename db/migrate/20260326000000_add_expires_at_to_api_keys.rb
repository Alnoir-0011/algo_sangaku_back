class AddExpiresAtToApiKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :api_keys, :expires_at, :datetime, null: false, default: -> { "NOW() + INTERVAL '7 days'" }
    add_index :api_keys, :expires_at
  end
end
