class RemoveTimezoneColumns < ActiveRecord::Migration[7.0]
  def change
    remove_column :users, :timezone, :string
    remove_column :bands, :timezone, :string
    remove_index :users, :timezone if index_exists?(:users, :timezone)
  end
end
