module ServiceErrors
  class Base < StandardError
    attr_reader :code, :user_message

    def initialize(user_message:, code:)
      @user_message = user_message
      @code = code
      super(user_message)
    end
  end

  class Validation < Base
    def initialize(user_message:)
      super(user_message: user_message, code: :validation)
    end
  end

  class Policy < Base
    def initialize(user_message:)
      super(user_message: user_message, code: :policy)
    end
  end

  class System < Base
    def initialize(user_message:)
      super(user_message: user_message, code: :system)
    end
  end
end

