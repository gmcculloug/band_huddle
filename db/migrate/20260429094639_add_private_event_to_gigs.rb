class AddPrivateEventToGigs < ActiveRecord::Migration[7.0]
  def change
    add_column :gigs, :private_event, :boolean, default: false, null: false
  end
end
