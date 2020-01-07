# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseTranslator::Yandex do
  let(:mock_response) { Struct.new(:status, :body) }

  describe '.access_token' do
    describe 'when set' do
      api_key = '12345'
      before { SiteSetting.translator_yandex_api_key = api_key }

      it 'should return back translator_yandex_api_key' do
        expect(described_class.access_token).to eq(api_key)
      end
    end
  end

  describe '.detect' do
    let(:post) { Fabricate(:post) }

    it 'should store the detected language in a custom field' do
      detected_lang = 'en'
      described_class.expects(:access_token).returns('12345')
      Excon.expects(:post).returns(mock_response.new(200, %{ { "code": 200, "lang": "#{detected_lang}" } })).once
      expect(described_class.detect(post)).to eq(detected_lang)

      2.times do
        expect(
          post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
        ).to eq(detected_lang)
      end
    end
  end

  describe '.translate' do
    let(:post) { Fabricate(:post) }

    it 'raises an error on failure' do
      described_class.expects(:access_token).returns('12345')
      described_class.expects(:detect).returns('en')

      Excon.expects(:post).returns(mock_response.new(
        400,
        { error: 'something went wrong', error_description: 'you passed in a wrong param' }.to_json
      ))

      expect { described_class.translate(post) }.to raise_error DiscourseTranslator::TranslatorError
    end
  end
end
