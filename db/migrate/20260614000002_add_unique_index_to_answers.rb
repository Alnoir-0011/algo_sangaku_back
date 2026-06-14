class AddUniqueIndexToAnswers < ActiveRecord::Migration[8.1]
  def change
    add_index :answers, :user_sangaku_save_id, unique: true, name: "index_answers_on_user_sangaku_save_id_unique"
    remove_index :answers, name: "index_answers_on_user_sangaku_save_id"
  end
end
