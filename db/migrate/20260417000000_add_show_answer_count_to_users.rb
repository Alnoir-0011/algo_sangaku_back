class AddShowAnswerCountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :show_answer_count, :boolean, default: false, null: false
  end
end
