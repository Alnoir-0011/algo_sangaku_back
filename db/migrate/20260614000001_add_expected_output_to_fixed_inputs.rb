class AddExpectedOutputToFixedInputs < ActiveRecord::Migration[8.1]
  def change
    add_column :fixed_inputs, :expected_output, :text
  end
end
