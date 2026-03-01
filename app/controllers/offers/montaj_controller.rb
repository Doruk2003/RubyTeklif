class Offers::MontajController < ApplicationController
  before_action :authorize_offers!

  def index
    # Placeholder for Montaj Teklif list
  end

  def new
    # Placeholder for Montaj Teklif create
  end

  private

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end
end
