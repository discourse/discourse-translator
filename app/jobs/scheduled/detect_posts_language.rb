# frozen_string_literal: true

module ::Jobs
  class DetectPostsLanguage < ::Jobs::Scheduled
    sidekiq_options retry: false
    every 5.minutes

    BATCH_SIZE = 100
    MAX_QUEUE_SIZE = 1000

    def execute(args)
      return unless SiteSetting.translator_enabled

      post_ids = Discourse.redis.spop(DiscourseTranslator::LANG_DETECT_NEEDED, MAX_QUEUE_SIZE)
      return if post_ids.blank?

      post_ids.each_slice(BATCH_SIZE) { |batch| process_batch(batch) }
    end

    private

    def process_batch(post_ids)
      posts = Post.where(id: post_ids).to_a
      posts.each do |post|
        DistributedMutex.synchronize("detect_translation_#{post.id}") do
          begin
            translator = "DiscourseTranslator::#{SiteSetting.translator}".constantize
            translator.detect(post)
          rescue ::DiscourseTranslator::ProblemCheckedTranslationError
            # problem-checked translation errors gracefully
          end
        end
      end
    end
  end
end
