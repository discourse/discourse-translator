# frozen_string_literal: true

module DiscourseTranslator
  class AutomaticTranslations
    def inject(plugin)
      plugin.on(:post_process_cooked) do |_, post|
        if SiteSetting.automatic_translation_target_languages.present? && post.user_id > 0
          Jobs.enqueue(:translate_translatable, type: "Post", translatable_id: post.id)
        end
      end

      plugin.on(:topic_created) do |topic|
        if SiteSetting.automatic_translation_target_languages.present? && topic.user_id > 0
          Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
        end
      end

      plugin.on(:topic_edited) do |topic|
        if SiteSetting.automatic_translation_target_languages.present? && topic.user_id > 0
          Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
        end
      end
    end
  end
end
