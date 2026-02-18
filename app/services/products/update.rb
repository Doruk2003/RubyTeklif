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
      response = @repository.update_with_audit_atomic(product_id: id, payload: payload, actor_id: actor_id)
      raise_from_response!(response, fallback: "Urun guncellenemedi.")

      product_id = extract_product_id(response) || id
      { id: product_id, payload: payload }
    end
  end
end
