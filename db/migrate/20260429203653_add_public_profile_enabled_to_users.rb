class AddPublicProfileEnabledToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :public_profile_enabled, :boolean, default: false, null: false
    add_index :users, :public_profile_enabled
  end
end
