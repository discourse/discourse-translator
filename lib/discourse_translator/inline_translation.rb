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

    SHOW_ORIGINAL_COOKIE = "discourse-translator-show-original"

    def inject(plugin)
      plugin.register_anonymous_cache_key :showoriginal do
        @request.cookies[SHOW_ORIGINAL_COOKIE].present? ? "1" : "0"
      end

      # since locales are eager loaded but translations may not,
      # always return early if topic and posts are in the user's effective_locale.
      # this prevents the need to load translations.

      plugin.register_modifier(:basic_post_serializer_cooked) do |cooked, serializer|
        if show_translation?(serializer.object, serializer.scope)
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        else
          cooked
        end
      end

      plugin.register_modifier(:topic_serializer_fancy_title) do |fancy_title, serializer|
        if show_translation?(serializer.object, serializer.scope)
          serializer
            .object
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        else
          fancy_title
        end
      end

      plugin.register_modifier(:topic_view_serializer_fancy_title) do |fancy_title, serializer|
        if show_translation?(serializer.object.topic, serializer.scope)
          serializer
            .object
            .topic
            .translation_for(InlineTranslation.effective_locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        else
          fancy_title
        end
      end

      plugin.add_to_serializer(:basic_post, :is_translated) do
        SiteSetting.experimental_inline_translation &&
          !object.locale_matches?(InlineTranslation.effective_locale) &&
          !scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE) &&
          object.translation_for(InlineTranslation.effective_locale).present?
      end

      plugin.add_to_serializer(:basic_post, :detected_language) do
        if SiteSetting.experimental_inline_translation && object.detected_locale.present?
          LocaleToLanguage.get_language(object.detected_locale)
        end
      end

      plugin.add_to_serializer(:topic_view, :show_translation_toggle) do
        return false if !SiteSetting.experimental_inline_translation
        # either the topic or any of the posts has a translation
        # also, check the locale first as it is cheaper than loading translation
        (
          !object.topic.locale_matches?(InlineTranslation.effective_locale) &&
            object.topic.translation_for(InlineTranslation.effective_locale).present?
        ) ||
          (
            object.posts.any? do |post|
              !post.locale_matches?(InlineTranslation.effective_locale) &&
                post.translation_for(InlineTranslation.effective_locale).present?
            end
          )
      end

      plugin.register_topic_preloader_associations(:content_locale) do
        SiteSetting.translator_enabled && SiteSetting.experimental_inline_translation
      end
      plugin.register_topic_preloader_associations(:translations) do
        SiteSetting.translator_enabled && SiteSetting.experimental_inline_translation
      end

      # categories

      plugin.register_modifier(:site_category_serializer_name) do |name, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          name
        else
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        end
      end

      # tags

      plugin.register_modifier(:topic_tags_serializer_name) do |tags, serializer|
        # %w[topics tags serializer name]
      end

      plugin.register_modifier(:sidebar_tag_serializer_name) do |name, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.object.locale_matches?(InlineTranslation.effective_locale) ||
             serializer.scope&.request&.params&.[]("show") == "original"
          name
        else
          serializer.object.translation_for(InlineTranslation.effective_locale).presence
        end
      end

      # plugin.register_modifier(:tag_serializer_name) { |name, serializer| "tag_serializer_name" }
    end

    def show_translation?(translatable, scope)
      SiteSetting.experimental_inline_translation &&
        !translatable.locale_matches?(InlineTranslation.effective_locale) &&
        !scope&.request&.cookies&.key?(SHOW_ORIGINAL_COOKIE)
    end
  end
end
