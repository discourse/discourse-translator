# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Topic do
  describe 'translator custom fields' do
    let(:topic) do
      Fabricate(:topic,
        title: 'my topic title to be translated',
        custom_fields: {
          ::DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD => 'en',
          ::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD => { 'de' => 'translation in de' }
        }
      )
    end

    before do
      SiteSetting.translator_enabled = true
    end

    after do
      SiteSetting.translator_enabled = false
    end

    it 'should reset custom fields when topic title has been updated' do
      topic.update!(title: 'this is an updated title')

      expect(
        topic.custom_fields[::DiscourseTranslator::DETECTED_TITLE_LANG_CUSTOM_FIELD]
      ).to be_nil

      expect(
        topic.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
      ).to be_nil
    end
  end
end
