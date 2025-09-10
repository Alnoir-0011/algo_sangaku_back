class CreateAnswers < ActiveRecord::Migration[8.0]
  def change
    create_table :answers do |t|
      t.references :user_sangaku_save, null: false, foreign_key: true
      t.text :source, null: false

      t.timestamps
    end
  end
end
