# frozen_string_literal: true

module DiscourseTranslator
  class AutomaticTranslations
    def inject(plugin)
      plugin.on(:post_process_cooked) do |_, post|
        if SiteSetting.experimental_content_localization
          Jobs.enqueue(:detect_translate_post, post_id: post.id)
        end
      end

      plugin.on(:topic_created) do |topic|
        if SiteSetting.experimental_content_localization
          Jobs.enqueue(:detect_translate_topic, topic_id: topic.id)
        end
      end

      plugin.on(:post_edited) do |post, topic_changed|
        if SiteSetting.experimental_content_localization && topic_changed
          Jobs.enqueue(:detect_translate_topic, topic_id: post.topic_id)
        end
      end
    end
  end
end
