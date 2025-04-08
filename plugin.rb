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
    Guardian.prepend(DiscourseTranslator::Extensions::GuardianExtension)
    Post.prepend(DiscourseTranslator::Extensions::PostExtension)
    Topic.prepend(DiscourseTranslator::Extensions::TopicExtension)
    Category.prepend(DiscourseTranslator::Extensions::CategoryExtension)
    Tag.prepend(DiscourseTranslator::Extensions::TagExtension)
    TopicViewSerializer.prepend(DiscourseTranslator::Extensions::TopicViewSerializerExtension)
  end

  add_to_serializer :post, :can_translate do
    scope.can_translate?(object)
  end

  DiscourseTranslator::ParallelTextTranslation.new.inject(self)
  DiscourseTranslator::InlineTranslation.new.inject(self)

  DiscourseTranslator::AutomaticTranslations.new.inject(self)
end
