# frozen_string_literal: true

require_relative "base"
require "json"

module DiscourseTranslator
  class DiscourseAi < Base
    MAX_DETECT_LOCALE_TEXT_LENGTH = 1000
    def self.language_supported?(_)
      true
    end

    def self.detect(topic_or_post)
      return unless required_settings_enabled

      topic_or_post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] ||= begin
        # we don't need that much text to determine the locale
        text = get_text(topic_or_post).truncate(MAX_DETECT_LOCALE_TEXT_LENGTH)

        get_ai_helper_output(
          text,
          CompletionPrompt.find_by(id: CompletionPrompt::DETECT_TEXT_LOCALE),
        )
      end
    end

    def self.translate(topic_or_post)
      return unless required_settings_enabled

      detected_lang = detect(topic_or_post)
      translated_text =
        from_custom_fields(topic_or_post) do
          get_ai_helper_output(
            get_text(topic_or_post),
            CompletionPrompt.find_by(id: CompletionPrompt::TRANSLATE),
          )
        end

      [detected_lang, translated_text]
    end

    private

    def self.get_ai_helper_output(text, prompt)
      ::DiscourseAi::AiHelper::Assistant.new.generate_and_send_prompt(
        prompt,
        text,
        Discourse.system_user,
      )[
        :suggestions
      ].first
    end

    def self.required_settings_enabled
      SiteSetting.translator_enabled && SiteSetting.translator == "DiscourseAi" &&
        SiteSetting.discourse_ai_enabled && SiteSetting.ai_helper_enabled
    end
  end
end
