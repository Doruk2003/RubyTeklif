# Module Template (Rails / MVC + Services)

This template is the standard structure for new modules (Offers, Orders, Invoices, Ledgers, Payroll, HR).

## Folder Structure

```
app/
  controllers/
    offers_controller.rb
  services/
    offers/
      create.rb
      repository.rb
      totals_calculator.rb
  queries/
    offers/
      index_query.rb
      show_query.rb
  forms/
    offers/
      create_form.rb
  views/
    offers/
      index.html.erb
      show.html.erb
      new.html.erb
```

## Conventions

- Controllers are thin: only parameter handling + responses.
- `Queries` read data (list/detail, filters).
- `Services` write data (create/update, calculations).
- `Forms` validate complex form input.
- Avoid direct API calls in controllers; route all to `Queries/Services`.

## Minimal Class Templates

### Query

```
module Offers
  class IndexQuery
    def initialize(client:)
      @client = client
    end

    def call
      data = @client.get("offers?select=id,offer_number,offer_date,gross_total,status,companies(name)&order=offer_date.desc")
      data.is_a?(Array) ? data : []
    end
  end
end
```

### Service

```
module Offers
  class Create
    def initialize(client:)
      @client = client
    end

    def call(payload)
      # normalize + calculate + insert
    end
  end
end
```

### Form

```
module Offers
  class CreateForm
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :company_id, :string
    attribute :offer_number, :string
    attribute :offer_date, :string
    attribute :status, :string
    attribute :items, default: []
  end
end
```
