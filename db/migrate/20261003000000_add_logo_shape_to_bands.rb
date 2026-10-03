class AddLogoShapeToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :logo_shape, :string, default: 'round', null: false
  end
end
