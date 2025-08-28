class CreateUserSangakuSaves < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sangaku_saves do |t|
      t.references :user, null: false, foreign_key: true
      t.references :sangaku, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_sangaku_saves, [ :user_id, :sangaku_id ], unique: true
  end
end
