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

    it 'should reset custom fields when post has been updated' do
      post.update_attributes(raw: 'this is an updated post')

      expect(
        post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]
      ).to eq(nil)

      expect(
        post.custom_fields[::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD]
      ).to eq({})
    end
  end
end
