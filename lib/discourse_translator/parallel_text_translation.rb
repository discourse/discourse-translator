# frozen_string_literal: true

module DiscourseTranslator
  class ParallelTextTranslation
    def inject(plugin)
      plugin.on(:post_process_cooked) do |_, post|
        if Guardian.new.can_detect_language?(post) && post.user_id > 0
          Jobs.enqueue(:detect_translatable_language, type: "Post", translatable_id: post.id)
        end
      end

      plugin.on(:topic_created) do |topic|
        if Guardian.new.can_detect_language?(topic.first_post) && topic.user_id > 0
          Jobs.enqueue(:detect_translatable_language, type: "Topic", translatable_id: topic.id)
        end
      end
    end
  end
end
