# frozen_string_literal: true

module DiscourseTranslator
  class InlineTranslation
    def inject(plugin)
      plugin.register_modifier(:basic_post_serializer_cooked) do |cooked, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.scope&.request&.params&.[]("show") == "original" ||
             serializer.object.detected_locale == I18n.locale.to_s.gsub("_", "-")
          cooked
        else
          serializer.object.translation_for(I18n.locale).presence
        end
      end

      plugin.register_modifier(:topic_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.scope&.request&.params&.[]("show") == "original" ||
             serializer.object.locale_matches?(I18n.locale)
          fancy_title
        else
          serializer.object.translation_for(I18n.locale).presence&.then { |t| Topic.fancy_title(t) }
        end
      end

      plugin.register_modifier(:topic_view_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_inline_translation ||
             serializer.scope&.request&.params&.[]("show") == "original" ||
             serializer.object.topic.locale_matches?(I18n.locale)
          fancy_title
        else
          serializer
            .object
            .topic
            .translation_for(I18n.locale)
            .presence
            &.then { |t| Topic.fancy_title(t) }
        end
      end

      plugin.add_to_serializer(
        :basic_post,
        :is_translated,
        include_condition: -> { SiteSetting.experimental_inline_translation },
      ) { !object.locale_matches?(I18n.locale) && object.translation_for(I18n.locale).present? }

      plugin.add_to_serializer(
        :topic_view,
        :is_translated,
        include_condition: -> { SiteSetting.experimental_inline_translation },
      ) do
        # since locales are eager loaded, but translations may not
        # return early if topic and posts are all in the user's locale
        if object.topic.locale_matches?(I18n.locale) &&
             object.posts.all? { |p| p.locale_matches?(I18n.locale) }
          return false
        end

        object.topic.translation_for(I18n.locale).present? ||
          object.posts.any? { |p| p.translation_for(I18n.locale).present? }
      end
    end
  end
end
