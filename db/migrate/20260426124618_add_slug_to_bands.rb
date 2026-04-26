class AddSlugToBands < ActiveRecord::Migration[7.0]
  def up
    add_column :bands, :slug, :string
    add_index :bands, :slug, unique: true, name: 'index_bands_on_slug'

    # Backfill existing bands using PostgreSQL string functions
    execute <<-SQL
      UPDATE bands
      SET slug = LOWER(
        REGEXP_REPLACE(
          REGEXP_REPLACE(name, '[^a-zA-Z0-9\\s-]', '', 'g'),
          '\\s+', '-', 'g'
        )
      )
    SQL
  end

  def down
    remove_index :bands, name: 'index_bands_on_slug'
    remove_column :bands, :slug
  end
end
