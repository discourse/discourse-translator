# frozen_string_literal: true

describe DiscourseTranslator::Provider::DiscourseAi do
  fab!(:post)
  fab!(:topic)

  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_translation_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.translator_enabled = true
    SiteSetting.translator_provider = "DiscourseAi"
  end

  describe ".language_supported?" do
    it "returns true when detected language is different from i18n locale" do
      I18n.stubs(:locale).returns(:xx)
      expect(described_class.language_supported?("any-language")).to eq(true)
    end

    it "returns false when detected language is same base language as i18n locale" do
      I18n.stubs(:locale).returns(:en_GB)
      expect(described_class.language_supported?("en")).to eq(false)
    end
  end

  describe ".detect!" do
    it "returns the detected language" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses([locale]) do
        expect(DiscourseTranslator::Provider::DiscourseAi.detect!(post)).to eq locale
      end
    end
  end

  describe ".translate_post!" do
    before do
      post.set_detected_locale("de")
      topic.set_detected_locale("de")
    end

    it "translates the post and returns [locale, translated_text]" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["some translated text"]) do
        translated_text = DiscourseTranslator::Provider::DiscourseAi.translate_post!(post)
        expect(translated_text).to eq "some translated text"
      end
    end

    it "sends the content for splitting and the split content for translation" do
      post.update(raw: "#{"a" * 3000} #{"b" * 3000}")
      DiscourseAi::Completions::Llm.with_prepared_responses(%w[lol wut]) do
        expect(DiscourseTranslator::Provider::DiscourseAi.translate_post!(post)).to eq "lolwut"
      end
    end
  end

  describe ".translate_topic!" do
    it "translates the topic" do
      allow(::DiscourseAi::TopicTranslator).to receive(:new).and_call_original
      DiscourseAi::Completions::Llm.with_prepared_responses(["some translated text"]) do
        translated_text = DiscourseTranslator::Provider::DiscourseAi.translate_topic!(topic)
        expect(translated_text).to eq "some translated text"
      end
    end
  end

  describe ".translate_text!" do
    it "returns the translated text" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["some translated text"]) do
        translated_text = DiscourseTranslator::Provider::DiscourseAi.translate_text!("derp")
        expect(translated_text).to eq "some translated text"
      end
    end
  end
end
