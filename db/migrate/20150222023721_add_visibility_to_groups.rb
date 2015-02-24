class AddVisibilityToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :visibility, :integer
  end
end
