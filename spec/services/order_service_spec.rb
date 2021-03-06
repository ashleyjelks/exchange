require 'rails_helper'

describe OrderService, type: :services do
  include_context 'use stripe mock'
  let(:order) { Fabricate(:order, external_charge_id: captured_charge.id) }
  let!(:line_items) { [Fabricate(:line_item, order: order, artwork_id: 'a-1'), Fabricate(:line_item, order: order, artwork_id: 'a-2', edition_set_id: 'es-1', quantity: 2)] }
  let(:user_id) { 'user-id' }
  describe '#reject!' do
    let(:artwork_inventory_deduct_request_status) { 200 }
    let(:edition_set_inventory_deduct_request_status) { 200 }
    let(:artwork_inventory_undeduct_request) { stub_request(:put, "#{Rails.application.config_for(:gravity)['api_v1_root']}/artwork/a-1/inventory").with(body: { undeduct: 1 }).to_return(status: artwork_inventory_deduct_request_status, body: {}.to_json) }
    let(:edition_set_inventory_undeduct_request) { stub_request(:put, "#{Rails.application.config_for(:gravity)['api_v1_root']}/artwork/a-2/edition_set/es-1/inventory").with(body: { undeduct: 2 }).to_return(status: edition_set_inventory_deduct_request_status, body: {}.to_json) }
    before do
      order.update! state: Order::SUBMITTED
    end
    context 'with a successful refund' do
      before do
        artwork_inventory_undeduct_request
        edition_set_inventory_undeduct_request
      end
      it 'calls to undeduct inventory' do
        OrderService.reject!(order, user_id)
        expect(artwork_inventory_undeduct_request).to have_been_requested
        expect(edition_set_inventory_undeduct_request).to have_been_requested
      end
      it 'records the transaction' do
        OrderService.reject!(order, user_id)
        expect(order.transactions.last.external_id).to_not eq nil
        expect(order.transactions.last.transaction_type).to eq Transaction::REFUND
        expect(order.transactions.last.status).to eq Transaction::SUCCESS
      end
      it 'updates the order state' do
        OrderService.reject!(order, user_id)
        expect(order.state).to eq Order::REJECTED
      end
    end
    context 'with an unsuccessful refund' do
      before do
        artwork_inventory_undeduct_request
        edition_set_inventory_undeduct_request
        StripeMock.prepare_card_error(:card_declined, :new_refund)
        expect { OrderService.reject!(order, user_id) }.to raise_error(Errors::PaymentError)
      end
      it 'raises a PaymentError and records the transaction' do
        expect(order.transactions.last.external_id).to eq captured_charge.id
        expect(order.transactions.last.transaction_type).to eq Transaction::REFUND
        expect(order.transactions.last.status).to eq Transaction::FAILURE
      end
      it 'does not undeduct inventory' do
        expect(artwork_inventory_undeduct_request).not_to have_been_requested
        expect(edition_set_inventory_undeduct_request).not_to have_been_requested
      end
    end
  end
end
