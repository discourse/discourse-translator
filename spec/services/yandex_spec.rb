# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseTranslator::Yandex do
  let(:mock_response) { Struct.new(:status, :body) }
  let(:detected_lang) { 'en' }

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
    let(:topic) { Fabricate(:topic) }
    let(:translated_text) { "some de text" }
    let(:target_lang) { "de" }

    context "works" do
      before do
        I18n.locale = target_lang
        Excon.expects(:post)
          .times(2)
          .returns(
            mock_response.new(200, %{ { "code": 200, "lang": "#{detected_lang}" } }),
            mock_response.new(200, %{ { "code": 200, "text": [ "#{translated_text}" ] } })
          )
      end

      it 'with posts' do
        expect(described_class.translate(post)).to eq([detected_lang, translated_text])
        expect(post.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]).to eq({ "de" => translated_text })
      end

      it 'with topic titles' do
        expect(described_class.translate(topic)).to eq([detected_lang, translated_text])
        expect(topic.custom_fields[DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]).to eq({ "de" => translated_text })
      end
    end

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
