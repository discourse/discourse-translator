# frozen_string_literal: true
module DiscourseTranslator
  module Extensions
    module GuardianExtension
      POST_DETECTION_BUFFER = 10.seconds

      def user_group_allow_translate?
        return false if !current_user
        current_user.in_any_groups?(SiteSetting.restrict_translation_by_group_map)
      end

      def poster_group_allow_translate?(post)
        return false if !current_user
        return true if SiteSetting.restrict_translation_by_poster_group_map.empty?
        return false if post.user.nil?
        post.user.in_any_groups?(SiteSetting.restrict_translation_by_poster_group_map)
      end

      def can_detect_language?(post)
        (
          SiteSetting.restrict_translation_by_poster_group_map.empty? ||
            post&.user&.in_any_groups?(SiteSetting.restrict_translation_by_poster_group_map)
        ) && post.raw.present? && post.post_type != Post.types[:small_action]
      end

      def can_translate?(post)
        return false if post.user&.bot?
        return false if !user_group_allow_translate?

        # we want to return false if the post is updated within a short buffer ago,
        # this prevents the 🌐from appearing and then disappearing if the lang is same as user's lang
        return false if post.updated_at > POST_DETECTION_BUFFER.ago && post.detected_locale.blank?

        locale = I18n.locale
        return false if post.locale_matches?(locale)
        poster_group_allow_translate?(post)
      end
    end
  end
end
