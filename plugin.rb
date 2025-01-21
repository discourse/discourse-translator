# frozen_string_literal: true

# name: discourse-translator
# about: Translates posts on Discourse using Microsoft, Google, Yandex, LibreTranslate, or Discourse AI translation APIs.
# meta_topic_id: 32630
# version: 0.3.0
# authors: Alan Tan
# url: https://github.com/discourse/discourse-translator

gem "aws-sdk-translate", "1.35.0", require: false

enabled_site_setting :translator_enabled
register_asset "stylesheets/common/post.scss"
register_asset "stylesheets/common/common.scss"

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

  reloadable_patch do
    Guardian.prepend(DiscourseTranslator::GuardianExtension)
    Post.prepend(DiscourseTranslator::PostExtension)
    Topic.prepend(DiscourseTranslator::TopicExtension)
  end

  on(:post_process_cooked) do |_, post|
    if Guardian.new.can_detect_language?(post)
      Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, post.id)
    end
  end

  add_to_serializer :post, :can_translate do
    scope.can_translate?(object)
  end

  add_to_serializer :post, :cooked, respect_plugin_enabled: false do
    return super() if cooked_hidden
    DiscourseTranslator::TranslatorHelper.translated_value(super(), object, scope)
  end

  add_to_serializer :basic_topic, :fancy_title do
    DiscourseTranslator::TranslatorHelper.translated_value(object.fancy_title, object, scope)
  end
end
