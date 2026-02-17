module ApplicationHelper
  def icon_link_button(path, label:, icon:, variant: :nav, class_name: nil, **options)
    variant_class = case variant.to_sym
                    when :new then "btn-new-record"
                    when :filter then "btn-filter-icon"
                    when :clear then "btn-clear-icon"
                    else "btn-home-nav"
                    end

    classes = [variant_class, class_name].compact.join(" ")
    data_options = (options[:data] || {}).merge(tip: label)
    aria_options = (options[:aria] || {}).merge(label: label)

    link_to path, options.merge(class: classes, data: data_options, aria: aria_options) do
      content_tag(:span, icon, class: "material-symbols-outlined", aria: { hidden: true })
    end
  end

  def icon_submit_button(label:, icon:, variant: :filter, class_name: nil, **options)
    variant_class = variant.to_sym == :clear ? "btn-clear-icon" : "btn-filter-icon"
    classes = [variant_class, class_name].compact.join(" ")
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
    classes = ["btn-home-nav", class_name].compact.join(" ")
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
end
