class UpdateUserSlugsToUsername < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        User.reset_column_information
        User.find_each do |user|
          # Parameterize username to match what generate_slug_after_create does
          base_slug = user.username.parameterize
          candidate_slug = base_slug

          # Ensure uniqueness by appending random numbers if needed
          while User.where(slug: candidate_slug).where.not(id: user.id).exists?
            candidate_slug = "#{base_slug}-#{rand(1000..9999)}"
          end

          user.update_column(:slug, candidate_slug)
        end
      end
    end
  end
end
