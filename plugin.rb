# frozen_string_literal: true

# name: discourse-translator
# about: Translates posts on Discourse using Microsoft, Google, Yandex or LibreTranslate translation APIs.
# meta_topic_id: 32630
# version: 0.3.0
# authors: Alan Tan
# url: https://github.com/discourse/discourse-translator

gem "aws-sdk-translate", "1.35.0", require: false

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/post.scss"

module ::DiscourseTranslator
  PLUGIN_NAME = "discourse-translator".freeze

  DETECTED_LANG_CUSTOM_FIELD = "post_detected_lang".freeze
  TRANSLATED_CUSTOM_FIELD = "translated_text".freeze
  LANG_DETECT_NEEDED = "lang_detect_needed".freeze
end

require_relative "lib/discourse_translator/engine"

after_initialize do
  register_problem_check ProblemCheck::MissingTranslatorApiKey
  register_problem_check ProblemCheck::TranslatorError

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)
  Topic.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  topic_view_post_custom_fields_allowlister { [::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD] }

  reloadable_patch do |plugin|
    Guardian.prepend(DiscourseTranslator::GuardianExtension)
    Post.prepend(DiscourseTranslator::PostExtension)
    Topic.prepend(DiscourseTranslator::TopicExtension)
  end

  add_to_serializer :post, :can_translate do
    return false if !SiteSetting.translator_enabled
    if !scope.user_group_allow_translate? || !scope.poster_group_allow_translate?(object)
      return false
    end
    return false if raw.blank? || post_type == Post.types[:small_action]

    detected_lang = post_custom_fields[::DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]

    if !detected_lang
      Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, object.id)
      false
    else
      detected_lang !=
        "DiscourseTranslator::#{SiteSetting.translator}::SUPPORTED_LANG_MAPPING".constantize[
          I18n.locale
        ]
    end
  end
end
