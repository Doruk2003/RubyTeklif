class Offers::DemonteController < ApplicationController
  before_action :authorize_offers!

  def index
    # Placeholder for Demonte Teklif list
  end

  def new
    # Placeholder for Demonte Teklif create
  end

  private

  def authorize_offers!
    authorize_with_policy!(OffersPolicy)
  end
end
