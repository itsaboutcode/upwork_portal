ActiveAdmin.register Tag do
  menu label: "Tags", priority: 3
  config.batch_actions = false
  permit_params :name, :active  # Permit the attributes you want to allow

  # Customize the index page
  index do
    selectable_column
    id_column
    column :name
    column :active
    actions
  end

  # Form for creating/editing tags
  form do |f|
    f.inputs do
      f.input :name
      f.input :active
    end
    f.actions
  end

  # Filters for searching
  filter :name
  filter :active
end
