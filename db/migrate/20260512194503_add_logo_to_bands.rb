class AddLogoToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :logo_filename, :string
    add_column :bands, :show_band_name, :boolean, default: true, null: false
  end
end
