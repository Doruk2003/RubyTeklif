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
      response = @repository.create_with_audit_atomic(payload: payload, actor_id: actor_id)
      raise_from_response!(response, fallback: "Urun olusturulamadi.")

      product_id = extract_product_id(response)
      raise ServiceErrors::System.new(user_message: "Urun ID alinamadi.") if product_id.blank?

      product_id
    end
  end
end
