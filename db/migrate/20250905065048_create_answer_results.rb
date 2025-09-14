class CreateAnswerResults < ActiveRecord::Migration[8.0]
  def change
    create_table :answer_results do |t|
      t.references :fixed_input, foreign_key: true
      t.references :answer, null: false, foreign_key: true
      t.text :output
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :answer_results, [ :fixed_input_id, :answer_id ], unique: true
  end
end
