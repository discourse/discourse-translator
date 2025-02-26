# frozen_string_literal: true

module DiscourseTranslator
  class InlineTranslation
    def inject(plugin)
      plugin.register_modifier(:basic_post_serializer_cooked) do |cooked, serializer|
        if !SiteSetting.experimental_topic_translation ||
             serializer.scope&.request&.params&.[]("show") == "original" ||
             serializer.object.detected_locale == I18n.locale.to_s.gsub("_", "-")
          cooked
        else
          serializer.object.translation_for(I18n.locale).presence
        end
      end

      plugin.register_modifier(:topic_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_topic_translation ||
             serializer.scope&.request&.params&.[]("show") == "original" ||
             serializer.object.locale_matches?(I18n.locale)
          fancy_title
        else
          serializer.object.translation_for(I18n.locale).presence&.then { |t| Topic.fancy_title(t) }
        end
      end

      plugin.register_modifier(:topic_view_serializer_fancy_title) do |fancy_title, serializer|
        if !SiteSetting.experimental_topic_translation ||
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
    end
  end
end
