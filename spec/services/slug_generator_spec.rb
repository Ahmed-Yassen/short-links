require 'rails_helper'

RSpec.describe SlugGenerator do
  let(:alphabet) { described_class::ALPHABET }
  let(:base) { described_class::BASE }

  describe '.encode' do
    context 'with valid positive integers' do
      it 'encodes ID 0 to the first character of the alphabet' do
        expect(described_class.encode(0)).to eq(alphabet[0])
      end

      it 'encodes ID 1 to the second character of the alphabet' do
        expect(described_class.encode(1)).to eq(alphabet[1])
      end

      it 'encodes the maximum single-digit value (Base - 1) correctly' do
        expect(described_class.encode(base - 1)).to eq(alphabet.last)
      end

      it 'handles the single-digit to double-digit transition' do
        encoded = described_class.encode(base)
        expect(encoded).to eq("#{alphabet[1]}#{alphabet[0]}")
        expect(encoded.length).to eq(2)
      end

      it 'handles large integers (producing longer strings)' do
        id = base**2
        encoded = described_class.encode(id)
        expect(encoded.length).to eq(3)
        expect(encoded).to eq("#{alphabet[1]}#{alphabet[0]}#{alphabet[0]}")
      end
    end

    context 'with string inputs representing integers' do
      it 'accepts a string "123" and treats it as integer 123' do
        expect(described_class.encode("123")).to eq(described_class.encode(123))
      end
    end

    context 'with invalid inputs' do
      it 'raises ArgumentError for non-numeric strings' do
        expect {
          described_class.encode("abc")
        }.to raise_error(ArgumentError, I18n.t('slug_generator.errors.invalid_input'))
      end

      it 'raises ArgumentError for floats/mixed garbage' do
        expect {
          described_class.encode("12abc")
        }.to raise_error(ArgumentError, I18n.t('slug_generator.errors.invalid_input'))
      end

      it 'raises ArgumentError for negative numbers' do
        expect { described_class.encode(-5) }.to raise_error(ArgumentError)
        expect { described_class.encode("-5") }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.decode' do
    context 'with valid slugs' do
      it 'decodes the first character of the alphabet to 0' do
        expect(described_class.decode(alphabet[0])).to eq(0)
      end

      it 'decodes the last character of the alphabet to Base - 1' do
        expect(described_class.decode(alphabet.last)).to eq(base - 1)
      end

      it 'decodes a multi-character slug correctly' do
        slug = "#{alphabet[1]}#{alphabet[0]}"
        expect(described_class.decode(slug)).to eq(base)
      end
    end

    context 'with invalid or missing inputs' do
      it 'returns nil if the slug contains characters not in the alphabet' do
        expect(described_class.decode('abc$')).to be_nil
      end

      it 'returns nil if the slug contains spaces' do
        expect(described_class.decode('abc ')).to be_nil
      end

      it 'returns nil if the slug is nil' do
        expect(described_class.decode(nil)).to be_nil
      end

      it 'returns nil if the slug is an empty string' do
        expect(described_class.decode("")).to be_nil
      end
    end
  end

  describe 'Bijectivity (Round-trip Consistency)' do
    it 'is reversible for a standard range of IDs' do
      (0..1000).each do |id|
        slug = described_class.encode(id)
        decoded_id = described_class.decode(slug)
        expect(decoded_id).to eq(id), "Failed for ID: #{id}"
      end
    end

    it 'remains consistent for very large 64-bit integers' do
      50.times do
        id = rand(1_000_000..9_999_999_999)
        slug = described_class.encode(id)
        decoded_id = described_class.decode(slug)
        expect(decoded_id).to eq(id)
      end
    end
  end
end
