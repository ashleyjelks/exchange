class Mutations::BaseMutation < GraphQL::Schema::RelayClassicMutation
  def validate_seller_request!(order)
    raise Errors::AuthError, 'Not permitted' unless order.seller_type == Order::PARTNER && context[:current_user]['partner_ids'].include?(order.seller_id)
  end

  def validate_buyer_request!(order)
    raise Errors::AuthError, 'Not permitted' unless context[:current_user]['id'] == order.buyer_id
  end
end
