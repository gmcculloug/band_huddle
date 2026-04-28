class MigrateGigTimesToUtcDatetime < ActiveRecord::Migration[7.0]
  def up
    add_column :gigs, :start_time_new, :datetime
    add_column :gigs, :end_time_new, :datetime
    # Existing time data has no timezone context — intentionally set to NULL
    remove_column :gigs, :start_time
    remove_column :gigs, :end_time
    rename_column :gigs, :start_time_new, :start_time
    rename_column :gigs, :end_time_new, :end_time
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
