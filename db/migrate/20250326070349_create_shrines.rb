class CreateShrines < ActiveRecord::Migration[8.0]
  def change
    create_table :shrines do |t|
      t.string :name, null: false
      t.string :address, null: false
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.string :place_id, null: false, index: { unique: true }

      t.timestamps
    end
  end
end
