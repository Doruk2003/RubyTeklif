module ProductImages
  class Reorder
    def initialize(client:, repository: nil)
      @repository = repository || ProductImages::Repository.new(client: client)
    end

    def move(product_id:, image_id:, user_id:, direction:)
      rows = @repository.list(product_id: product_id, user_id: user_id)
      index = rows.index { |row| row["id"].to_s == image_id.to_s }
      if index.nil?
        raise ServiceErrors::Validation.new(user_message: "Fotograf bulunamadi.")
      end

      target_index = case direction.to_s
                     when "up"
                       index - 1
                     when "down"
                       index + 1
                     else
                       raise ServiceErrors::Validation.new(user_message: "Gecersiz siralama yonu.")
                     end

      return true if target_index.negative? || target_index >= rows.size

      current_row = rows[index]
      target_row = rows[target_index]
      current_sort = sort_value(current_row, index)
      target_sort = sort_value(target_row, target_index)

      @repository.update_active!(
        image_id: current_row["id"],
        product_id: product_id,
        user_id: user_id,
        attrs: { sort_order: target_sort, updated_at: Time.now.utc.iso8601 }
      )
      @repository.update_active!(
        image_id: target_row["id"],
        product_id: product_id,
        user_id: user_id,
        attrs: { sort_order: current_sort, updated_at: Time.now.utc.iso8601 }
      )

      true
    end

    private

    def sort_value(row, index)
      value = row["sort_order"].to_i
      value.positive? ? value : (index + 1)
    end
  end
end
