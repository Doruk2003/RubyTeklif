module Products
  class Create
    include ServiceSupport

    def initialize(client: nil, repository: nil)
      @repository = repository || Products::Repository.new(client: client)
    end

    def call(form_payload:, actor_id:)
      form = Products::UpsertForm.new(form_payload)
      validate_form!(form)

      payload = form.normalized_attributes
      validate_uniqueness!(payload: payload)
      response = @repository.create_with_audit_atomic(payload: payload, actor_id: actor_id)
      raise_from_response!(response, fallback: "Urun olusturulamadi.")

      product_id = extract_product_id(response)
      raise ServiceErrors::System.new(user_message: "Urun ID alinamadi.") if product_id.blank?

      product_id
    end

    private

    def validate_uniqueness!(payload:)
      return if payload[:sku].to_s.blank? && payload[:barcode].to_s.blank?

      sku_taken = @repository.sku_taken?(sku: payload[:sku])
      barcode_taken = @repository.barcode_taken?(barcode: payload[:barcode])
      return unless sku_taken || barcode_taken

      raise ServiceErrors::Validation.new(user_message: "SKU veya barkod zaten kayitli.")
    end
  end
end
