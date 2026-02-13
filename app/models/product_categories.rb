module ProductCategories
  VALUES = %w[general raw_material finished_goods service spare_part].freeze

  LABELS = {
    "general" => "Genel",
    "raw_material" => "Hammadde",
    "finished_goods" => "Mamul",
    "service" => "Hizmet",
    "spare_part" => "Yedek Parca"
  }.freeze

  OPTIONS = VALUES.map { |value| [LABELS.fetch(value), value] }.freeze

  module_function

  def label_for(value)
    LABELS[value.to_s] || value.to_s
  end
end
