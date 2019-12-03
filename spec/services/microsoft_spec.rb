# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseTranslator::Microsoft do
  let(:mock_response) { Struct.new(:status, :body) }

  after do
    Discourse.redis.del(described_class.cache_key)
  end

  describe '.access_token' do
    describe 'when access_token has been cached' do
      let(:cache_key) { 'KEY' }

      it 'should return from cache' do
        Discourse.redis.set(described_class.cache_key, cache_key)
        expect(described_class.access_token).to eq(cache_key)
      end
    end

    describe 'azure portal' do
      SiteSetting.translator_azure_subscription_key = 'some key'

      it 'should return the access_token and cache it' do
        access_token = 'some token'
        mock_response = Struct.new(:status, :body)
        response = mock_response.new(200, access_token)

        Excon.expects(:post).returns(response)
        Discourse.redis.expects(:setex).with(described_class.cache_key, 8.minutes, access_token)

        described_class.access_token
      end

      describe 'when access_token is not valid' do
        it 'should raise the right error' do
          stub_request(:post, "https://api.cognitive.microsoft.com/sts/v1.0/issueToken?Subscription-Key=some%20key").
            to_return(status: 200, body: "")

          expect { described_class.access_token }
            .to raise_error(DiscourseTranslator::TranslatorError)
        end
      end
    end

    it 'should return the access_token and cache it' do
      access_token = 'some token'
      mock_response = Struct.new(:status, :body)

      response = mock_response.new(
        200,
        access_token
      )

      Excon.expects(:post).returns(response)
      Discourse.redis.expects(:setex).with(described_class.cache_key, 480, access_token)

      described_class.access_token
    end

    it 'raises an error on failure' do
      Excon.expects(:post).returns(mock_response.new(
        400,
        { error: 'something went wrong', error_description: 'you passed in a wrong param' }.to_json
      ))

      expect { described_class.access_token }.to raise_error DiscourseTranslator::TranslatorError
    end
  end

  describe '.detect' do
    let(:post) { Fabricate(:post) }

    let(:url) do
      uri = URI(described_class::DETECT_URI)
      uri.query = URI.encode_www_form(described_class.default_query)
      uri.to_s
    end

    let(:detected_lang) { 'en' }

    before do
      Discourse.redis.set(described_class.cache_key, '12345')

      stub_request(:post, url)
        .to_return(status: 200, body: [{ "language" => detected_lang }].to_json)
    end

    it 'should store the detected language in a custom field' do
      described_class.detect(post)

      2.times do
        expect(
          post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
        ).to eq(detected_lang)
      end
    end
  end

  describe '.translate' do
    let(:post) { Fabricate(:post) }

    before do
      Discourse.redis.set(described_class.cache_key, '12345')
      post.custom_fields = { DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => 'en' }
      post.save_custom_fields
    end

    after do
      Discourse.redis.del(described_class.cache_key)
    end

    it 'should work' do
      I18n.locale = 'de'

      uri = URI(described_class::TRANSLATE_URI)

      uri.query = URI.encode_www_form(described_class.default_query.merge(
        "from" => "en",
        "to" => I18n.locale,
        "textType" => "html"
      ))

      stub_request(:post, uri.to_s).to_return(
        status: 200,
        body: [{ "translations" => [{ "text" => "some de text" }] }].to_json,
      )

      expect(described_class.translate(post)).to eq([
        "en", "some de text"
      ])
    end

    it 'should return the right value when post has already been translated' do
      I18n.locale = 'en'

      post.custom_fields = {
        DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => 'tr',
        DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => {
          'en' => 'some english text'
        }
      }

      post.save_custom_fields

      expect(described_class.translate(post)).to eq(['tr', 'some english text'])
    end

    it 'raises an error if detected language of the post is not supported' do
      post.custom_fields = { DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => 'donkey' }
      post.save_custom_fields

      expect { described_class.translate(post) }.to raise_error(
        DiscourseTranslator::TranslatorError, I18n.t('translator.failed')
      )
    end

    it 'raises an error if the post is too long to be translated' do
      post.update_columns(cooked: "*" * (DiscourseTranslator::Microsoft::LENGTH_LIMIT + 1))

      expect { described_class.translate(post) }.to raise_error(
        DiscourseTranslator::TranslatorError, I18n.t('translator.too_long')
      )
    end

    it 'raises an error on failure' do
      Excon.expects(:post).returns(mock_response.new(
        400,
        { error: 'something went wrong', error_description: 'you passed in a wrong param' }.to_json
      ))

      expect { described_class.translate(post) }.to raise_error DiscourseTranslator::TranslatorError
    end
  end
end
