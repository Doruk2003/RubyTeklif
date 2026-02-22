module Products
  class Update
    include ServiceSupport

    def initialize(client: nil, repository: nil)
      @repository = repository || Products::Repository.new(client: client)
    end

    def call(id:, form_payload:, actor_id:)
      form = Products::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      validate_uniqueness!(id: id, payload: payload)
      response = @repository.update_with_audit_atomic(product_id: id, payload: payload, actor_id: actor_id)
      raise_from_response!(response, fallback: "Urun guncellenemedi.")

      product_id = extract_product_id(response) || id
      { id: product_id, payload: payload }
    end

    private

    def validate_uniqueness!(id:, payload:)
      sku_taken = @repository.sku_taken?(sku: payload[:sku], exclude_product_id: id)
      barcode_taken = @repository.barcode_taken?(barcode: payload[:barcode], exclude_product_id: id)
      return unless sku_taken || barcode_taken

      raise ServiceErrors::Validation.new(user_message: "SKU veya barkod zaten kayitli.")
    end
  end
end
