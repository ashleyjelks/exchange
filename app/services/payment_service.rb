module PaymentService
  def self.authorize_charge(source_id, destination_id, amount, currency_code)
    Stripe::Charge.create(
      amount: amount,
      currency: currency_code,
      description: 'Artsy',
      source: source_id,
      destination: destination_id,
      capture: false
    )
  rescue Stripe::StripeError => e
    body = e.json_body[:error]
    failed_charge = {
      amount: amount,
      id: body[:charge],
      source_id: source_id,
      destination_id: destination_id,
      failure_code: body[:code],
      failure_message: body[:message]
    }
    raise Errors::PaymentError.new(e.message, failed_charge)
  end
end