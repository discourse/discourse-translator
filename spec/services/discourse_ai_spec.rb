# frozen_string_literal: true

require "rails_helper"

describe DiscourseTranslator::DiscourseAi do
  fab!(:post)

  before do
    Fabricate(:fake_model).tap do |fake_llm|
      SiteSetting.public_send("ai_helper_model=", "custom:#{fake_llm.id}")
    end
    SiteSetting.ai_helper_enabled = true
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "DiscourseAi"
  end

  describe ".detect" do
    it "stores the detected language in a custom field" do
      locale = "de"
      DiscourseAi::Completions::Llm.with_prepared_responses(["<output>de</output>"]) do
        DiscourseTranslator::DiscourseAi.detect(post)
        post.save_custom_fields
      end

      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to eq locale
    end

    it "truncates to MAX LENGTH" do
      truncated_text =
        post.cooked.truncate(DiscourseTranslator::DiscourseAi::MAX_DETECT_LOCALE_TEXT_LENGTH)
      expect_any_instance_of(::DiscourseAi::AiHelper::Assistant).to receive(
        :generate_and_send_prompt,
      ).with(
        CompletionPrompt.find_by(id: CompletionPrompt::DETECT_TEXT_LOCALE),
        truncated_text,
        Discourse.system_user,
      ).and_call_original

      DiscourseAi::Completions::Llm.with_prepared_responses(["<output>de</output>"]) do
        DiscourseTranslator::DiscourseAi.detect(post)
      end
    end
  end

  describe ".translate" do
    before do
      post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] = "de"
      post.save_custom_fields
    end

    it "translates the post and returns [locale, translated_text]" do
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["<output>some translated text</output>", "<output>translated</output>"],
      ) do
        locale, translated_text = DiscourseTranslator::DiscourseAi.translate(post)
        expect(locale).to eq "de"
        expect(translated_text).to eq "some translated text"
      end
    end
  end
end
