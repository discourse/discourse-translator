# frozen_string_literal: true

module DiscourseTranslator
  class AutomaticTranslations
    def inject(plugin)
      plugin.on(:post_process_cooked) do |_, post|
        if translatable?(post)
          Jobs.enqueue(:translate_translatable, type: "Post", translatable_id: post.id)
        end

        if SiteSetting.experimental_content_localization
          Jobs.enqueue(:detect_translate_post, post_id: post.id)
        end
      end

      plugin.on(:topic_created) do |topic|
        if translatable?(topic)
          Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
        end
      end

      plugin.on(:topic_edited) do |topic|
        if translatable?(topic)
          Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
        end
      end
    end

    def translatable?(content)
      return false if SiteSetting.automatic_translation_target_languages.blank?
      return false if content.user_id <= 0
      return false if SiteSetting.automatic_translation_backfill_rate <= 0
      return true unless SiteSetting.automatic_translation_backfill_limit_to_public_content

      public_categories = Category.where(read_restricted: false).pluck(:id)

      if content.is_a?(Post)
        public_categories.include?(content.topic.category_id)
      elsif content.is_a?(Topic)
        public_categories.include?(content.category_id)
      else
        false
      end
    end
  end
end
