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

after_initialize do
  module ::DiscourseTranslator
    PLUGIN_NAME = "discourse_translator".freeze
    DETECTED_LANG_CUSTOM_FIELD = "post_detected_lang".freeze
    TRANSLATED_CUSTOM_FIELD = "translated_text".freeze

    autoload :Microsoft,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/microsoft"
    autoload :Google,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/google"
    autoload :Amazon,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/amazon"
    autoload :Yandex,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/yandex"
    autoload :Deepl,
             "#{Rails.root}/plugins/discourse-translator/services/discourse_translator/deepl"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseTranslator
    end
  end

  class DiscourseTranslator::TranslatorController < ::ApplicationController
    before_action :ensure_logged_in

    def translate
      raise PluginDisabled if !SiteSetting.translator_enabled

      if !current_user.staff?
        RateLimiter.new(
          current_user,
          "translate_post",
          SiteSetting.max_translations_per_minute,
          1.minute,
        ).performed!
      end

      params.require(:post_id)
      post = Post.find_by(id: params[:post_id])
      raise Discourse::InvalidParameters.new(:post_id) if post.blank?
      guardian.ensure_can_see!(post)

      if !guardian.user_group_allowed?
        raise Discourse::InvalidAccess.new(
                "not_in_group",
                SiteSetting.restrict_translation_by_group,
                custom_message: "not_in_group.user_not_in_group",
                group: current_user.groups.pluck(:id),
              )
      end

      if !guardian.post_group_allowed?(post)
        raise Discourse::InvalidAccess.new(
                "not_in_group",
                SiteSetting.restrict_translation_by_poster_group,
                custom_message: "not_in_group.poster_not_in_group",
              )
      end

      begin
        detected_lang, translation =
          "DiscourseTranslator::#{SiteSetting.translator}".constantize.translate(post)
        render json: { translation: translation, detected_lang: detected_lang }, status: 200
      rescue ::DiscourseTranslator::TranslatorError => e
        render_json_error e.message, status: 422
      end
    end
  end

  Post.register_custom_field_type(::DiscourseTranslator::TRANSLATED_CUSTOM_FIELD, :json)

  class ::Post < ActiveRecord::Base
    before_update :clear_translator_custom_fields, if: :raw_changed?

    private

    def clear_translator_custom_fields
      return if !SiteSetting.translator_enabled

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
  end

  TopicView.on_preload do |topic_view|
    topic_view.instance_variable_set(:@posts, topic_view.posts.includes(:content_locale))
  end

  add_to_serializer :post, :can_translate do
    scope.can_translate?(object)
  end

  DiscourseTranslator::ParallelTextTranslation.new.inject(self)
end
