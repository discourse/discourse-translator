# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Post do
  describe 'translator custom fields' do
    let(:post) do
      Fabricate(:post,
        raw: 'this is a sample post',
        custom_fields: {
          ::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD => 'en',
          ::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => { 'en' => 'lol' }
        }
      )
    end

    before do
      SiteSetting.translator_enabled = true
    end

    after do
      SiteSetting.translator_enabled = false
    end

    it 'should reset custom fields when post has been updated' do
      post.update!(raw: 'this is an updated post')

      expect(
        post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
      ).to be_nil

      expect(
        post.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
      ).to be_nil
    end
  end
end
