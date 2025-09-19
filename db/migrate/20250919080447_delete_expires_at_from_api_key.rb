class DeleteExpiresAtFromApiKey < ActiveRecord::Migration[8.0]
  def change
    remove_column :api_keys, :expires_at, :datetime
  end
end
