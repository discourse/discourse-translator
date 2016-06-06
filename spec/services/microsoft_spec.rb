require 'rails_helper'

RSpec.describe DiscourseTranslator::Microsoft do
  let(:mock_response) { Struct.new(:status, :body) }

  describe '.access_token' do
    describe 'when access_token has been cached' do
      let(:cache_key) { 'KEY' }

      it 'should return from cache' do
        begin
          $redis.set(described_class.cache_key, cache_key)
          expect(described_class.access_token).to eq(cache_key)
        ensure
          $redis.del(described_class.cache_key)
        end
      end
    end

    it 'should return the access_token and cache it' do
      access_token = 'some token'
      MockResponse = Struct.new(:status, :body)

      response = MockResponse.new(
        200,
        { access_token: access_token, expires_in: '600' }.to_json
      )

      Excon.expects(:post).returns(response)
      $redis.expects(:setex).with(described_class.cache_key, 540, access_token)

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

    it 'should store the detected language in a custom field' do
      detected_lang = 'en'
      described_class.expects(:access_token).returns('12345')
      Excon.expects(:post).returns(mock_response.new(200, "<ArrayOfstring><string>en</string></ArrayOfstring>")).once
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
