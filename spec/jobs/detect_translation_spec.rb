# frozen_string_literal: true

require "aws-sdk-translate"

describe Jobs::DetectTranslation do
  before do
    SiteSetting.translator = "Amazon"
    client = Aws::Translate::Client.new(stub_responses: true)
    client.stub_responses(
      :translate_text,
      { translated_text: "大丈夫", source_language_code: "en", target_language_code: "jp" },
    )
    Aws::Translate::Client.stubs(:new).returns(client)
  end

  it "does not detect translation if translator disabled" do
    SiteSetting.translator_enabled = false

    post = Fabricate(:post)
    Jobs::DetectTranslation.new.execute(post_id: post.id)

    expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil
  end

  it "does not detect translation for small posts" do
    SiteSetting.translator_enabled = false

    post = Fabricate(:small_action)
    Jobs::DetectTranslation.new.execute(post_id: post.id)

    expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil
  end

  describe "translator enabled" do
    before { SiteSetting.translator_enabled = true }

    it "does not detect translation if post does not exist" do
      post = Fabricate(:post)
      post.destroy

      Jobs::DetectTranslation.new.execute(post_id: post.id)

      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil
    end

    it "detects translation" do
      post = Fabricate(:post, raw: "this is a sample post")

      messages = MessageBus.track_publish { Jobs::DetectTranslation.new.execute(post_id: post.id) }

      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq("en")
      expect(messages.size).to eq(1)
    end

    it "does not publish change if no change in translation" do
      post = Fabricate(:post, raw: "this is a sample post")
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "en"
      post.save_custom_fields

      messages = MessageBus.track_publish { Jobs::DetectTranslation.new.execute(post_id: post.id) }
      expect(messages.size).to eq(0)
    end
  end
end
