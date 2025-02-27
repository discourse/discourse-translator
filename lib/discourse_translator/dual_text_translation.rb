# frozen_string_literal: true

module DiscourseTranslator
  class DualTextTranslation
    def inject(plugin)
      # in dual-text translations,
      # we don't want to send the post for detection if automatic translation already happens,
      # as automatic translations send content for language detection as a side effect of translating

      plugin.on(:post_process_cooked) do |_, post|
        if SiteSetting.automatic_translation_target_languages.blank? &&
             Guardian.new.can_detect_language?(post) && post.user_id > 0
          Jobs.enqueue(:detect_translatable_language, type: "Post", translatable_id: post.id)
        end
      end

      plugin.on(:topic_created) do |topic|
        if SiteSetting.automatic_translation_target_languages.blank? &&
             Guardian.new.can_detect_language?(topic.first_post) && topic.user_id > 0
          Jobs.enqueue(:detect_translatable_language, type: "Topic", translatable_id: topic.id)
        end
      end
    end
  end
end
