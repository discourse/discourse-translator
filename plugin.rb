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

  LANG_DETECT_NEEDED = "lang_detect_needed".freeze
end

require_relative "lib/discourse_translator/engine"

after_initialize do
  register_problem_check ProblemCheck::MissingTranslatorApiKey
  register_problem_check ProblemCheck::TranslatorError

  reloadable_patch do
    Guardian.prepend(DiscourseTranslator::GuardianExtension)
    Post.prepend(DiscourseTranslator::PostExtension)
    Topic.prepend(DiscourseTranslator::TopicExtension)
    TopicViewSerializer.prepend(DiscourseTranslator::TopicViewSerializerExtension)
  end

  on(:post_process_cooked) do |_, post|
    if Guardian.new.can_detect_language?(post)
      Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, post.id)
    end
  end

  on(:post_process_cooked) do |_, post|
    if SiteSetting.automatic_translation_target_languages.present?
      Jobs.enqueue(:translate_translatable, type: "Post", translatable_id: post.id)
    end
  end

  on(:topic_created) do |topic|
    if SiteSetting.automatic_translation_target_languages.present?
      Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
    end
  end

  on(:topic_edited) do |topic|
    if SiteSetting.automatic_translation_target_languages.present?
      Jobs.enqueue(:translate_translatable, type: "Topic", translatable_id: topic.id)
    end
  end

  add_to_serializer :post, :can_translate do
    scope.can_translate?(object)
  end

  add_to_serializer :post, :translated_cooked do
    if !SiteSetting.experimental_topic_translation || scope.request.params["show"] == "original"
      return nil
    end
    object.translation_for(I18n.locale) || nil
  end

  add_to_serializer :topic_view, :translated_title do
    if !SiteSetting.experimental_topic_translation || scope.request.params["show"] == "original"
      return nil
    end
    object.topic.translation_for(I18n.locale) || nil
  end
end
