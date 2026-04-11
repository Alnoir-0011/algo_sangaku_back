class CreateGenerateSourceCallLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :generate_source_call_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :called_at, null: false

      t.timestamps
    end

    add_index :generate_source_call_logs, [ :user_id, :called_at ]
  end
end
