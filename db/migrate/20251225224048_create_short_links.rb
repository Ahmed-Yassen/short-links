class CreateShortLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :short_links do |t|
      t.text :original_url, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :short_links, :slug, unique: true
    add_index :short_links, :original_url, unique: true
  end
end
