module GravityService
  def self.fetch_partner(partner_id)
    Rails.cache.fetch("gravity_partner_#{partner_id}", expire_in: Rails.application.config_for(:gravity)['partner_cache_in_seconds']) do
      Adapters::GravityV1.get("/partner/#{partner_id}/all")
    end
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Unable to find partner'
  rescue Adapters::GravityError, StandardError => e
    raise Errors::OrderError, e.message
  end

  def self.get_merchant_account(partner_id)
    merchant_account = Adapters::GravityV1.get('/merchant_accounts', params: { partner_id: partner_id }).first
    raise Errors::OrderError, 'Partner does not have merchant account' if merchant_account.nil?
    merchant_account
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Unable to find partner or merchant account'
  rescue Adapters::GravityError, StandardError => e
    raise Errors::OrderError, e.message
  end

  def self.get_credit_card(credit_card_id)
    Adapters::GravityV1.get("/credit_card/#{credit_card_id}")
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Credit card not found'
  rescue Adapters::GravityError, StandardError => e
    raise Errors::OrderError, e.message
  end

  def self.get_artwork(artwork_id)
    Adapters::GravityV1.get("/artwork/#{artwork_id}")
  rescue Adapters::GravityError, StandardError => e
    Rails.logger.warn("Could not fetch artwork #{artwork_id} from gravity: #{e.message}")
    nil
  end

  def self.fetch_partner_location(partner_id)
    partner = fetch_partner(partner_id)
    location = Rails.cache.fetch("gravity_partner_location_#{partner[:billing_location_id]}", expire_in: Rails.application.config_for(:gravity)['partner_cache_in_seconds']) do
      Adapters::GravityV1.get("/partner/#{partner_id}/location/#{partner[:billing_location_id]}")
    end
    location.slice(:address, :address_2, :city, :state, :country, :postal_code)
  end

  def self.deduct_inventory(line_item)
    if line_item.edition_set_id
      Adapters::GravityV1.put("/artwork/#{line_item.artwork_id}/edition_set/#{line_item.edition_set_id}/inventory", params: { deduct: line_item.quantity })
    else
      Adapters::GravityV1.put("/artwork/#{line_item.artwork_id}/inventory", params: { deduct: line_item.quantity })
    end
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Credit card not found'
  rescue Adapters::GravityError => e
    raise Errors::InventoryError.new(e.message, line_item)
  end

  def self.undeduct_inventory(line_item)
    if line_item.edition_set_id
      Adapters::GravityV1.put("/artwork/#{line_item.artwork_id}/edition_set/#{line_item.edition_set_id}/inventory", params: { undeduct: line_item.quantity })
    else
      Adapters::GravityV1.put("/artwork/#{line_item.artwork_id}/inventory", params: { undeduct: line_item.quantity })
    end
  rescue Adapters::GravityNotFoundError
    raise Errors::OrderError, 'Credit card not found'
  rescue Adapters::GravityError => e
    raise Errors::InventoryError.new(e.message, line_item)
  end
end
