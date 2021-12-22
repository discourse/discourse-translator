# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseTranslator::Amazon do
  let(:mock_response) { Struct.new(:status, :body) }
  let!(:client) { Aws::Translate::Client.new(stub_responses: true) }
  let(:stub_client_response) do
    client.stub_responses(:translate_text, {
      translated_text: "Probando traducciones", source_language_code: "en", target_language_code: "es"
    })
  end

  before do
    stub_client_response
    Aws::Translate::Client.stubs(:new).returns(client)
  end

  describe '.detect' do
    let(:post) { Fabricate(:post) }
    let(:text) { post.cooked.truncate(described_class::MAXLENGTH, omission: nil) }
    let(:detected_lang) { 'en' }

    it 'should store the detected language in a custom field' do

      expect(described_class.detect(post)).to eq(detected_lang)

      2.times do
        expect(
          post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
        ).to eq(detected_lang)
      end
    end

    it 'should truncate string to 5000 characters and still process the request' do
      length = 6000
      post.cooked = rand(36**length).to_s(36)
      expect(described_class.detect(post)).to eq(detected_lang)
    end
  end

  describe '.translate' do
    let(:post) { Fabricate(:post) }

    it 'raises an error when trying to translate an unsupported language' do
      client.stub_responses(:translate_text, "UnsupportedLanguagePairException", {
        translated_text: "Probando traducciones", source_language_code: "en", target_language_code: "es"
      })

      expect { described_class.translate(post) }.to raise_error(I18n.t('translator.failed'))
    end
  end
end
