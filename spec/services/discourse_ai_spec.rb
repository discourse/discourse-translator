# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::DiscourseAi do
  before do
    SiteSetting.translator_enabled = true
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
  end

  describe ".detect" do
    let(:post) { Fabricate(:post) }

    it "stores the detected language in a custom field" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses(["<output>de</output>"]) do
        DiscourseTranslator::DiscourseAi.detect(post)
      end

      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq locale
    end

    it "truncates to MAX LENGTH" do
      truncated_text = post.cooked.truncate(DiscourseTranslator::DiscourseAi::MAX_DETECT_LOCALE_TEXT_LENGTH)
      expect_any_instance_of(::DiscourseAi::AiHelper::Assistant)
        .to receive(:generate_and_send_prompt)
              .with(
                CompletionPrompt.find_by(id: CompletionPrompt::DETECT_TEXT_LOCALE),
                truncated_text,
                Discourse.system_user
              ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses(["<output>de</output>"]) do
        DiscourseTranslator::DiscourseAi.detect(post)
      end
    end

    it "returns if settings are not correct" do

    end
  end

  describe ".translate" do
    it "translates the post and returns [locale, translated_text]" do
      post = Fabricate(:post)
      DiscourseAi::Completions::Llm.with_prepared_responses(["<output>some translated text</output>", "<output>translated</output>"]) do
        locale, translated_text = DiscourseTranslator::DiscourseAi.translate(post)
        expect(locale).to eq "de"
        expect(translated_text).to eq "some translated text"
      end
    end
  end
end
