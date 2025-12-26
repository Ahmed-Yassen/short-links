require 'rails_helper'

RSpec.describe IdSequencer do
  describe '.next_id' do
    let(:table_name) { 'short_links' }

    it 'returns an Integer' do
      id = described_class.next_id(table_name)
      expect(id).to be_a(Integer)
    end

    it 'increments the ID on subsequent calls' do
      first_id = described_class.next_id(table_name)
      second_id = described_class.next_id(table_name)

      expect(second_id).to eq(first_id + 1)
    end

    it 'does not insert a record into the table' do
      expect {
        described_class.next_id(table_name)
      }.not_to change(ShortLink, :count)
    end
  end
end
