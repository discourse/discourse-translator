# frozen_string_literal: true
module DiscourseTranslator::GuardianExtension
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
    return false if !user_group_allow_translate?

    # we will deal with regionalized_strings (not syms) when comparing locales
    # e.g. "en_GB"
    #      not "en-GB"
    #      nor :en_GB (I18n.locale)
    detected_lang =
      post.custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD].to_s.sub("-", "_")
    return false if detected_lang.blank?

    detected_lang != I18n.locale.to_s &&
      "DiscourseTranslator::#{SiteSetting.translator}".constantize.language_supported?(
        detected_lang,
      )
  end
end
