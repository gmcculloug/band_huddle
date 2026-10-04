class AddSocialMediaLinksToBands < ActiveRecord::Migration[7.0]
  def change
    add_column :bands, :social_media_links, :jsonb, default: {}, null: false
  end
end
