class CreateSangakus < ActiveRecord::Migration[8.0]
  def change
    create_table :sangakus do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.text :source, null: false
      t.integer :difficulty, null: false, default: 0
      t.references :user, null: false, foreign_key: true
      t.references :shrine, foreign_key: true

      t.timestamps
    end
  end
end
