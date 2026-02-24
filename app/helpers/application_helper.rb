module ApplicationHelper
  FILTER_GRID_LAYOUTS = {
    standard: "rt-filter-grid--4-wide-first",
    two: "rt-filter-grid--2",
    three_wide_first: "rt-filter-grid--3-wide-first",
    four: "rt-filter-grid--4",
    four_wide_first: "rt-filter-grid--4-wide-first",
    seven: "rt-filter-grid--7",
    seven_wide_first: "rt-filter-grid--7-wide-first"
  }.freeze

  def filter_form_with(url:, layout: :standard, class_name: nil, **options, &block)
    layout_class = FILTER_GRID_LAYOUTS.fetch(layout.to_sym) { FILTER_GRID_LAYOUTS[:standard] }
    classes = ["rt-filter-grid", layout_class, "app-form-standard", class_name, options.delete(:class)].compact.join(" ")

    form_options = { url: url, method: :get, local: true }.merge(options)
    form_options[:class] = classes
    form_with(**form_options, &block)
  end

  def filter_actions_row(class_name: nil, **options, &block)
    classes = ["rt-filter-grid-actions", "d-flex", "w-100", "align-items-end", "justify-content-end", "gap-2", class_name, options.delete(:class)].compact.join(" ")
    content_tag(:div, capture(&block), options.merge(class: classes))
  end

  def app_form_class(*extra_classes)
    ["app-form-standard", *extra_classes].flatten.compact.join(" ")
  end

  def app_table_wrapper(class_name: nil, &block)
    classes = ["table-responsive", "app-list-standard", class_name].compact.join(" ")
    content_tag(:div, capture(&block), class: classes)
  end

  def icon_link_button(path, label:, icon:, variant: :nav, class_name: nil, **options)
    classes = ["btn", "btn-outline-secondary", "rt-icon-btn-layout", class_name].compact.join(" ")
    data_options = (options[:data] || {}).merge(tip: label)
    aria_options = (options[:aria] || {}).merge(label: label)

    link_to path, options.merge(class: classes, data: data_options, aria: aria_options) do
      content_tag(:span, icon, class: "material-symbols-outlined", aria: { hidden: true })
    end
  end

  def icon_submit_button(label:, icon:, variant: :filter, class_name: nil, **options)
    classes = ["btn", "btn-outline-secondary", "rt-icon-btn-layout", class_name].compact.join(" ")
    data_options = (options[:data] || {}).merge(tip: label)
    aria_options = (options[:aria] || {}).merge(label: label)

    button_tag(type: "submit", class: classes, data: data_options, aria: aria_options) do
      content_tag(:span, icon, class: "material-symbols-outlined", aria: { hidden: true })
    end
  end

  def new_record_button(label, path, class_name: nil, **options)
    icon_link_button(path, label: label, icon: "add", variant: :new, class_name: class_name, **options)
  end

  def home_nav_button(path = home_path, label: "Ana Sayfa", class_name: nil, icon: "dashboard", **options)
    icon_link_button(path, label: label, icon: icon, variant: :nav, class_name: class_name, **options)
  end

  def filter_submit_button(label: "Filtrele", class_name: nil, icon: "filter_alt", **options)
    icon_submit_button(label: label, icon: icon, variant: :filter, class_name: class_name, **options)
  end

  def clear_filter_button(path, label: "Temizle", class_name: nil, icon: "close", **options)
    icon_link_button(path, label: label, icon: icon, variant: :clear, class_name: class_name, **options)
  end

  def edit_record_button(path, label: "Düzenle", class_name: nil, **options)
    icon_link_button(path, label: label, icon: "edit", variant: :nav, class_name: class_name, **options)
  end

  def list_nav_button(path, label: "Listeye Dön", class_name: nil, **options)
    icon_link_button(path, label: label, icon: "format_list_bulleted", variant: :nav, class_name: class_name, **options)
  end

  def filter_panel_toggle_button(label_open: "Filtreleri Aç", class_name: nil, target: nil)
    classes = ["btn", "btn-outline-secondary", "rt-icon-btn-layout", class_name].compact.join(" ")
    data_options = { tip: label_open, filter_panel_toggle: true }
    data_options[:filter_panel_target] = target if target.present?

    button_tag(type: "button", class: classes, data: data_options, aria: { label: label_open, expanded: "false" }) do
      content_tag(
        :span,
        "filter_list",
        class: "material-symbols-outlined rt-filter-toggle-icon",
        aria: { hidden: true },
        data: { filter_panel_icon: true }
      )
    end
  end

  def product_image_public_url(storage_path)
    path = storage_path.to_s
    return "" if path.blank?

    bucket = ENV.fetch("SUPABASE_PRODUCTS_BUCKET", "product-images")
    encoded_path = path.split("/").map { |segment| ERB::Util.url_encode(segment).gsub("+", "%20") }.join("/")
    "#{ENV.fetch("SUPABASE_URL")}/storage/v1/object/public/#{bucket}/#{encoded_path}"
  rescue KeyError
    ""
  end
end
