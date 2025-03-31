# frozen_string_literal: true

module DiscourseTranslator
  class InlineTranslation
    def self.effective_locale
      if LocaleMatcher.user_locale_is_default? || LocaleMatcher.user_locale_in_target_languages?
        I18n.locale
      else
        SiteSetting.default_locale
      end
    end

    def inject(plugin)
      # since locales are eager loaded but translations may not,
      # always return early if topic and posts are in the user's effective_locale.
      # this prevents the need to load translations.

      plugin.register_modifier(:basic_post_serializer_cooked) do |cooked, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          cooked
        else
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        end
      end

      plugin.register_modifier(:topic_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          fancy_title
        else
          serializer
            .object
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        end
      end

      plugin.register_modifier(:topic_view_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.topic.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          fancy_title
        else
          serializer
            .object
            .topic
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        end
      end

      plugin.add_to_serializer(:basic_post, :is_translated) do
        SiteSetting.experimental_inline_translation &&
          !object.locale_matches?(InlineTranslation.effective_locale) &&
          object.translation_for(InlineTranslation.effective_locale).present?
      end

      plugin.add_to_serializer(:topic_view, :is_translated) do
        SiteSetting.experimental_inline_translation &&
          !object.topic.locale_matches?(InlineTranslation.effective_locale) &&
          object.topic.translation_for(InlineTranslation.effective_locale).present?
      end
    end
  end
end
