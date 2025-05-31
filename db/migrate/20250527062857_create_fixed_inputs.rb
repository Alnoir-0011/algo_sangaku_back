class CreateFixedInputs < ActiveRecord::Migration[8.0]
  def change
    create_table :fixed_inputs do |t|
      t.text :content, null: false
      t.references :sangaku, null: false, foreign_key: true

      t.timestamps
    end

    add_index :fixed_inputs, [ :content, :sangaku_id ], unique: true
  end
end
