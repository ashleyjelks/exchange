require 'rails_helper'

describe Api::GraphqlController, type: :request do
  describe 'order query field permissions' do
    include_context 'GraphQL Client'
    let(:partner_id) { 'partner-1' }
    let(:user_id) { 'user-i' }
    let!(:order) { Fabricate(:order, seller_id: partner_id, buyer_id: user_id, updated_at: 1.day.ago, shipping_total_cents: 100_00, commission_fee_cents: 30_00, transaction_fee_cents: 20_00) }
    let!(:line_item) { Fabricate(:line_item, price_cents: 1000_00, order: order) }
    context 'as buyer' do
      let(:jwt_partner_ids) { [] }
      let(:jwt_user_id) { user_id }
      let(:order_query_with_seller_fields) do
        <<-GRAPHQL
          query($id: ID!) {
            order(id: $id) {
              id
              commissionFeeCents
              transactionFeeCents
              sellerTotalCents
              buyerTotalCents
            }
          }
        GRAPHQL
      end
      it 'returns nil for seller_only fields' do
        result = client.execute(order_query_with_seller_fields, id: order.id)
        expect(result.data.order.commission_fee_cents).to be_nil
        expect(result.data.order.transaction_fee_cents).to be_nil
        expect(result.data.order.seller_total_cents).to be_nil
        expect(result.data.order.buyer_total_cents).to eq 1100_00
      end
    end

    context 'as seller' do
      let(:jwt_user_id) { 'gallery-person-1' }
      let(:jwt_partner_ids) { [partner_id] }
      let(:order_query_with_buyer_fields) do
        <<-GRAPHQL
          query($id: ID!) {
            order(id: $id) {
              id
              buyerTotalCents
              commissionFeeCents
              sellerTotalCents
            }
          }
        GRAPHQL
      end
      it 'returns seller_only fields' do
        result = client.execute(order_query_with_buyer_fields, id: order.id)
        expect(result.data.order.buyer_total_cents).to eq 1100_00
        expect(result.data.order.seller_total_cents).to eq 1050_00
        expect(result.data.order.commission_fee_cents).to eq 30_00
      end
    end
  end
end
