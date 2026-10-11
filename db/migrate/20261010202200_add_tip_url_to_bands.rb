class AddTipUrlToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :tip_url, :string
    add_column :bands, :tip_text, :string, limit: 80
  end
end
